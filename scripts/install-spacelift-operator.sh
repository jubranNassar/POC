#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"


# Function to check if operator pods are ready
check_operator_pods_ready() {
    local ready_pods
    ready_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
    
    if [ "$ready_pods" -gt 0 ]; then
        local total_pods
        total_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$ready_pods" -gt 0 ]; then
            return 0
        fi
    fi
    return 1
}

# Function to wait for operator pods to be ready
wait_for_operator_pods() {
    if wait_with_timeout "check_operator_pods_ready" 30 2 "Spacelift operator pods to be ready"; then
        local ready_pods
        ready_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
        local total_pods
        total_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | wc -l || echo "0")
        print_success "All operator pods are ready! ($ready_pods/$total_pods)"
    else
        kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc || true
        return 1
    fi
}

# Function to validate operator installation
validate_operator() {
    print_status "Validating Spacelift operator installation..."
    
    # Check if namespace exists
    if kubectl get namespace spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1; then
        print_success "✓ Spacelift operator namespace exists"
    else
        print_error "✗ Spacelift operator namespace not found"
        return 1
    fi
    
    # Check if pods are running
    local running_pods
    running_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
    if [ "$running_pods" -gt 0 ]; then
        print_success "✓ Operator pods are running ($running_pods pods)"
        kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc
    else
        print_error "✗ No operator pods are running"
        kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc || true
        return 1
    fi
    
    # Check if CRDs are installed
    if kubectl get crd workerpools.workers.spacelift.io --context kind-spacelift-poc >/dev/null 2>&1; then
        print_success "✓ WorkerPool CRD is installed"
    else
        print_warning "⚠ WorkerPool CRD not found (may still be installing)"
    fi
    
    return 0
}

# Function to display operator info
show_operator_info() {
    echo -e "\n${GREEN}🎉 Spacelift Worker Pool Controller is installed!${NC}\n"
    
    echo -e "${BLUE}Operator Information:${NC}"
    echo "  - Namespace: spacelift-worker-controller-system"
    echo "  - Context: kind-spacelift-poc"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Create worker pool credentials (private key + CSR)"
    echo "2. Register worker pool in Spacelift UI/API"
    echo "3. Create WorkerPool resource in Kubernetes"
    echo "4. Deploy sample infrastructure stacks"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  - Check operator: kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc"
    echo "  - View logs: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-workerpool-controller"
    echo "  - List CRDs: kubectl get crd --context kind-spacelift-poc | grep spacelift"
    echo "  - Create WorkerPool: kubectl apply -f workerpool.yaml --context kind-spacelift-poc"
    
    echo -e "\n${YELLOW}Note:${NC} You'll need a Spacelift account and API credentials to create actual worker pools."
}

# Main execution
main() {
    print_status "Installing Spacelift Worker Pool Controller..."
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    check_command "kubectl"
    check_command "helm"
    print_success "kubectl and helm are available"
    
    # Check if Kind cluster is running
    check_kind_cluster
    
    # Check if operator is already installed via Helm
    if helm list -n spacelift-worker-controller-system --kube-context kind-spacelift-poc | grep -q "spacelift-workerpool-controller"; then
        print_warning "Spacelift operator appears to already be installed"
        if validate_operator; then
            print_success "Existing operator installation is healthy"
            show_operator_info
            exit 0
        else
            print_warning "Existing operator installation is unhealthy. Reinstalling..."
            helm uninstall spacelift-workerpool-controller -n spacelift-worker-controller-system --kube-context kind-spacelift-poc || true
            kubectl delete namespace spacelift-worker-controller-system --context kind-spacelift-poc || true
            sleep 5
        fi
    fi
    
    # Add Spacelift Helm repository
    print_status "Adding Spacelift Helm repository..."
    helm repo add spacelift https://downloads.spacelift.io/helm >/dev/null 2>&1
    helm repo update >/dev/null 2>&1
    print_success "Spacelift Helm repository added and updated"
    
    # Install the operator using Helm
    print_status "Installing Spacelift operator with Helm..."
    helm upgrade spacelift-workerpool-controller spacelift/spacelift-workerpool-controller \
        --install \
        --namespace spacelift-worker-controller-system \
        --create-namespace \
        --kube-context kind-spacelift-poc
    
    # Wait for operator pods to be ready
    wait_for_operator_pods
    
    # Validate installation
    if validate_operator; then
        print_success "Spacelift operator validation completed successfully"
    else
        print_error "Spacelift operator validation failed"
        print_error "Check the logs with: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-workerpool-controller"
        exit 1
    fi
    
    # Deploy IMDS mock for AWS credential simulation
    print_status "Deploying IMDS mock for AWS credential simulation..."
    if [ -x "$(dirname "$0")/deploy-imds-mock.sh" ]; then
        "$(dirname "$0")/deploy-imds-mock.sh"
    else
        print_error "IMDS mock deployment script not found or not executable"
        print_error "Please ensure ./scripts/deploy-imds-mock.sh exists and is executable"
        exit 1
    fi
    
    # Show operator information
    show_operator_info
}

# Handle script interruption
setup_interrupt_handler "Installation"

# Run main function
main "$@"