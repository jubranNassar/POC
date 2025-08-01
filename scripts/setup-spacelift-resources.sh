#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"


# Configuration file for storing account settings
CONFIG_FILE=".spacelift-poc-config"

# Function to get or prompt for Spacelift account alias
get_account_alias() {
    local account_alias=""
    
    # Try to read from config file first
    if [ -f "$CONFIG_FILE" ]; then
        account_alias=$(grep "^SPACELIFT_ACCOUNT_ALIAS=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-)
        if [ -n "$account_alias" ]; then
            print_status "Using saved account alias: $account_alias"
            export SPACELIFT_ACCOUNT_ALIAS="$account_alias"
            return 0
        fi
    fi
    
    # Prompt for account alias
    echo ""
    print_status "Spacelift account alias is required for authentication"
    print_status "Your account alias is the subdomain in your Spacelift URL"
    print_status "For example, if your URL is https://mycompany.app.spacelift.io/, your alias is 'mycompany'"
    echo ""
    read -p "Enter your Spacelift account alias: " account_alias
    
    if [ -z "$account_alias" ]; then
        print_error "Account alias cannot be empty"
        exit 1
    fi
    
    # Save to config file
    echo "SPACELIFT_ACCOUNT_ALIAS=$account_alias" > "$CONFIG_FILE"
    print_success "Account alias saved to $CONFIG_FILE for future use"
    
    export SPACELIFT_ACCOUNT_ALIAS="$account_alias"
}

# Function to authenticate with Spacelift
authenticate_spacelift() {
    print_status "Checking Spacelift authentication..."
    
    # Check if already authenticated
    if spacectl profile current >/dev/null 2>&1; then
        local current_profile
        current_profile=$(spacectl profile current 2>/dev/null | grep "Current profile:" | cut -d: -f2 | xargs)
        print_success "Already authenticated with profile: $current_profile"
        
        # Verify the authentication works
        if spacectl whoami >/dev/null 2>&1; then
            local account_name
            account_name=$(spacectl account current 2>/dev/null | grep "Name:" | cut -d: -f2 | xargs)
            print_success "Connected to Spacelift account: $account_name"
            return 0
        else
            print_warning "Authentication appears stale, re-authenticating..."
        fi
    fi

    print_status "Starting Spacelift authentication..."
    print_status "This will open your browser for login"

    # Get account alias
    get_account_alias

    # Interactive login with account alias
    spacectl profile login "$SPACELIFT_ACCOUNT_ALIAS"

    # Verify authentication worked
    if spacectl whoami >/dev/null 2>&1; then
        local account_name
        account_name=$(spacectl account current 2>/dev/null | grep "Name:" | cut -d: -f2 | xargs)
        print_success "Successfully authenticated to Spacelift account: $account_name"
    else
        print_error "Authentication failed"
        exit 1
    fi
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check required commands
    check_command "tofu"
    check_command "spacectl"
    
    # Check if CSR file exists
    require_file "certs/spacelift.csr" "Please run ./scripts/generate-worker-pool-certs.sh first"
    
    print_success "All prerequisites validated"
}

# Function to setup Tofu environment for Spacelift
setup_tofu_env() {
    print_status "Setting up Tofu environment for Spacelift..."
    export SPACELIFT_API_TOKEN=$(spacectl profile export-token)
}

# Function to initialize Tofu
init_tofu() {
    print_status "Initializing Tofu..."
    
    cd spacelift-config
    
    if [ ! -f ".terraform.lock.hcl" ]; then
        tofu init
        print_success "Tofu initialized"
    else
        print_status "Tofu already initialized"
    fi
    
    cd ..
}

# Function to plan Tofu changes
plan_tofu() {
    print_status "Planning Tofu changes..."
    
    cd spacelift-config
    
    tofu plan -out=tfplan
    
    cd ..
    
    print_success "Tofu plan completed"
    
    echo ""
    if ! confirm_action "Do you want to apply these changes"; then
        print_status "Tofu apply cancelled"
        return 1
    fi
    
    return 0
}

# Function to apply Tofu changes
apply_tofu() {
    print_status "Applying Tofu changes..."
    
    cd spacelift-config
    
    tofu apply tfplan
    
    # Save the worker pool config to file
    tofu output -raw worker_pool_config > ../certs/spacelift-workerpool.config
    
    cd ..
    
    print_success "Tofu apply completed"
    print_success "Worker pool configuration saved to certs/spacelift-workerpool.config"
}

# Function to show created resources
show_resources() {
    print_status "Retrieving created resources..."
    
    cd spacelift-config
    
    local worker_pool_id
    local space_id
    local context_id
    
    worker_pool_id=$(tofu output -raw worker_pool_id 2>/dev/null || echo "N/A")
    space_id=$(tofu output -raw space_id 2>/dev/null || echo "N/A")
    context_id=$(tofu output -raw context_id 2>/dev/null || echo "N/A")
    
    cd ..
    
    echo -e "\n${GREEN}🎉 Spacelift Resources Created!${NC}\n"
    
    echo -e "${BLUE}Created Resources:${NC}"
    echo "  - Worker Pool ID: $worker_pool_id"
    echo "  - Space ID: $space_id"
    echo "  - Context ID: $context_id"
    echo "  - Worker Pool Config: certs/spacelift-workerpool.config"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Create the WorkerPool in Kubernetes:"
    echo "   ./scripts/create-workerpool-k8s.sh"
    echo ""
    echo "2. Verify worker pool in Spacelift UI:"
    echo "   - Go to Worker pools in your Spacelift account"
    echo "   - You should see 'poc-local-k8s-pool'"
    echo ""
    echo "3. Create sample stacks using this worker pool"
}

# Function to destroy resources (cleanup)
destroy_resources() {
    print_warning "This will destroy all Spacelift resources created by this configuration"
    if ! confirm_action "Are you sure you want to continue"; then
        print_status "Destroy cancelled"
        return 0
    fi
    
    print_status "Destroying Spacelift resources..."
    
    cd spacelift-config
    
    tofu destroy -auto-approve
    
    cd ..
    
    print_success "Spacelift resources destroyed"
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  apply     Create/update Spacelift resources (default)"
    echo "  destroy   Destroy all Spacelift resources"
    echo "  plan      Show planned changes without applying"
    echo "  help      Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - spacectl (Spacelift CLI) must be installed"
    echo "  - You'll be prompted to login to Spacelift via browser"
    echo "  - CSR file must exist (run ./scripts/generate-worker-pool-certs.sh first)"
}

# Main execution
main() {
    local command="${1:-apply}"
    
    case "$command" in
        "apply")
            print_status "Setting up Spacelift resources..."
            validate_prerequisites
            authenticate_spacelift
            setup_tofu_env
            init_tofu
            if plan_tofu; then
                apply_tofu
                show_resources
            fi
            ;;
        "destroy")
            validate_prerequisites
            authenticate_spacelift
            setup_tofu_env
            init_tofu
            destroy_resources
            ;;
        "plan")
            validate_prerequisites
            authenticate_spacelift
            setup_tofu_env
            init_tofu
            cd spacelift-config
            tofu plan
            cd ..
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Handle script interruption
setup_interrupt_handler "Setup"

# Run main function
main "$@"