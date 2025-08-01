#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install $1 and try again."
        case "$1" in
            "terraform")
                echo "Installation guides:"
                echo "  - macOS: brew install terraform"
                echo "  - Linux: https://learn.hashicorp.com/tutorials/terraform/install-cli"
                echo "  - Windows: choco install terraform"
                ;;
            "spacectl")
                echo "Installation guides:"
                echo "  - macOS: brew install spacelift-io/spacelift/spacectl"
                echo "  - Linux: https://github.com/spacelift-io/spacectl#installation"
                echo "  - Windows: https://github.com/spacelift-io/spacectl#installation"
                ;;
        esac
        exit 1
    fi
}

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
    check_command "terraform"
    check_command "spacectl"
    
    # Check if CSR file exists
    if [ ! -f "certs/spacelift.csr" ]; then
        print_error "CSR file not found: certs/spacelift.csr"
        print_error "Please run ./scripts/generate-worker-pool-certs.sh first"
        exit 1
    fi
    
    print_success "All prerequisites validated"
}

# Function to setup Terraform environment for Spacelift
setup_terraform_env() {
    print_status "Setting up Terraform environment for Spacelift..."
    export SPACELIFT_API_TOKEN=$(spacectl profile export-token)
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd spacelift-config
    
    if [ ! -f ".terraform.lock.hcl" ]; then
        terraform init
        print_success "Terraform initialized"
    else
        print_status "Terraform already initialized"
    fi
    
    cd ..
}

# Function to plan Terraform changes
plan_terraform() {
    print_status "Planning Terraform changes..."
    
    cd spacelift-config
    
    terraform plan -out=tfplan
    
    cd ..
    
    print_success "Terraform plan completed"
    
    echo ""
    read -p "Do you want to apply these changes? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Terraform apply cancelled"
        return 1
    fi
    
    return 0
}

# Function to apply Terraform changes
apply_terraform() {
    print_status "Applying Terraform changes..."
    
    cd spacelift-config
    
    terraform apply tfplan
    
    # Save the worker pool config to file
    terraform output -raw worker_pool_config > ../certs/spacelift-workerpool.config
    
    cd ..
    
    print_success "Terraform apply completed"
    print_success "Worker pool configuration saved to certs/spacelift-workerpool.config"
}

# Function to show created resources
show_resources() {
    print_status "Retrieving created resources..."
    
    cd spacelift-config
    
    local worker_pool_id
    local space_id
    local context_id
    
    worker_pool_id=$(terraform output -raw worker_pool_id 2>/dev/null || echo "N/A")
    space_id=$(terraform output -raw space_id 2>/dev/null || echo "N/A")
    context_id=$(terraform output -raw context_id 2>/dev/null || echo "N/A")
    
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
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Destroy cancelled"
        return 0
    fi
    
    print_status "Destroying Spacelift resources..."
    
    cd spacelift-config
    
    terraform destroy -auto-approve
    
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
            setup_terraform_env
            init_terraform
            if plan_terraform; then
                apply_terraform
                show_resources
            fi
            ;;
        "destroy")
            validate_prerequisites
            authenticate_spacelift
            setup_terraform_env
            init_terraform
            destroy_resources
            ;;
        "plan")
            validate_prerequisites
            authenticate_spacelift
            setup_terraform_env
            init_terraform
            cd spacelift-config
            terraform plan
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
trap 'print_error "Setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"