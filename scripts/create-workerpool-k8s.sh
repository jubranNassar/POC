#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"


# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check required commands
    check_command "kubectl"
    check_command "base64"
    
    # Check if Kind cluster is accessible
    check_kind_cluster
    
    # Check if Spacelift operator is installed
    check_spacelift_operator
    
    # Check if required files exist
    require_file "certs/spacelift.key" "Please run ./scripts/generate-worker-pool-certs.sh first"
    require_file "certs/spacelift-workerpool.config" "Steps to get this file:\n1. Go to your Spacelift account\n2. Navigate to 'Worker pools'\n3. Create a worker pool using certs/spacelift.csr\n4. Download the configuration and save as certs/spacelift-workerpool.config"
    
    print_success "All prerequisites validated"
}

# Function to create Kubernetes secret
create_secret() {
    print_status "Creating Kubernetes secret with worker pool credentials..."
    
    # Encode private key to base64
    local private_key_b64
    private_key_b64=$(base64 -i certs/spacelift.key)
    
    # Check if secret already exists
    if kubectl get secret spacelift-worker-pool-credentials -n spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1; then
        print_warning "Secret 'spacelift-worker-pool-credentials' already exists"
        if confirm_action "Do you want to recreate it"; then
            kubectl delete secret spacelift-worker-pool-credentials -n spacelift-worker-controller-system --context kind-spacelift-poc
            print_status "Deleted existing secret"
        else
            print_status "Using existing secret"
            return 0
        fi
    fi
    
    # Create the secret
    kubectl create secret generic spacelift-worker-pool-credentials \
        --namespace=spacelift-worker-controller-system \
        --from-literal=privateKey="$private_key_b64" \
        --from-file=token=certs/spacelift-workerpool.config \
        --context kind-spacelift-poc
    
    print_success "Secret created successfully"
}

# Function to create WorkerPool resource
create_workerpool() {
    print_status "Creating WorkerPool Kubernetes resource..."
    
    # Check if WorkerPool already exists
    if kubectl get workerpool spacelift-poc-pool -n spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1; then
        print_warning "WorkerPool 'spacelift-poc-pool' already exists"
        if confirm_action "Do you want to recreate it"; then
            kubectl delete workerpool spacelift-poc-pool -n spacelift-worker-controller-system --context kind-spacelift-poc
            print_status "Deleted existing WorkerPool"
        else
            print_status "Using existing WorkerPool"
            return 0
        fi
    fi
    
    # Create WorkerPool manifest
    cat > /tmp/workerpool.yaml << EOF
apiVersion: workers.spacelift.io/v1beta1
kind: WorkerPool
metadata:
  name: spacelift-poc-pool
  namespace: spacelift-worker-controller-system
spec:
  poolSize: 1
  token:
    secretKeyRef:
      name: spacelift-worker-pool-credentials
      key: token
  privateKey:
    secretKeyRef:
      name: spacelift-worker-pool-credentials
      key: privateKey
EOF
    
    # Apply the WorkerPool
    kubectl apply -f /tmp/workerpool.yaml --context kind-spacelift-poc
    
    # Clean up temp file
    rm /tmp/workerpool.yaml
    
    print_success "WorkerPool resource created successfully"
}

# Function to validate WorkerPool setup
validate_setup() {
    print_status "Validating WorkerPool setup..."
    
    # Check if WorkerPool exists
    if kubectl get workerpool spacelift-poc-pool -n spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1; then
        print_success "✓ WorkerPool resource exists"
        kubectl get workerpool spacelift-poc-pool -n spacelift-worker-controller-system --context kind-spacelift-poc
    else
        print_error "✗ WorkerPool resource not found"
        return 1
    fi
    
    # Check if secret exists
    if kubectl get secret spacelift-worker-pool-credentials -n spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1; then
        print_success "✓ Worker pool credentials secret exists"
    else
        print_error "✗ Worker pool credentials secret not found"
        return 1
    fi
    
    return 0
}

# Function to show status and next steps
show_next_steps() {
    echo -e "\n${GREEN}🎉 WorkerPool Setup Complete!${NC}\n"
    
    echo -e "${BLUE}Created Resources:${NC}"
    echo "  - Secret: spacelift-worker-pool-credentials"
    echo "  - WorkerPool: spacelift-poc-pool"
    echo "  - Namespace: spacelift-worker-controller-system"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  - Check WorkerPool: kubectl get workerpool -n spacelift-worker-controller-system --context kind-spacelift-poc"
    echo "  - Check Workers: kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker"
    echo "  - Worker Logs: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker"
    echo "  - Describe WorkerPool: kubectl describe workerpool spacelift-poc-pool -n spacelift-worker-controller-system --context kind-spacelift-poc"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Verify the worker pool appears in your Spacelift account"
    echo "2. Create Spacelift stacks that use this worker pool"
    echo "3. Deploy sample infrastructure targeting LocalStack"
    
    echo -e "\n${YELLOW}Note:${NC}"
    echo "It may take a minute or two for worker pods to start and register with Spacelift."
}

# Main execution
main() {
    print_status "Setting up Spacelift WorkerPool in Kubernetes..."
    
    # Validate prerequisites
    validate_prerequisites
    
    # Create Kubernetes secret
    create_secret
    
    # Create WorkerPool resource
    create_workerpool
    
    # Validate setup
    if validate_setup; then
        print_success "WorkerPool setup validation completed successfully"
    else
        print_error "WorkerPool setup validation failed"
        exit 1
    fi
    
    # Show next steps
    show_next_steps
}

# Handle script interruption
setup_interrupt_handler "WorkerPool setup"

# Run main function
main "$@"