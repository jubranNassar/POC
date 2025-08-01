#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"


# Function to wait for cluster to be ready
wait_for_cluster() {
    wait_with_timeout "kubectl cluster-info --context kind-spacelift-poc >/dev/null 2>&1" 30 2 "cluster to be ready"
}

# Function to validate cluster
validate_cluster() {
    print_status "Validating cluster setup..."
    
    # Check nodes
    local nodes
    nodes=$(kubectl get nodes --context kind-spacelift-poc --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$nodes" -gt 0 ]; then
        print_success "✓ Cluster has $nodes node(s)"
        kubectl get nodes --context kind-spacelift-poc
    else
        print_error "✗ No nodes found in cluster"
        return 1
    fi
    
    # Check system pods
    local ready_pods
    ready_pods=$(kubectl get pods -n kube-system --context kind-spacelift-poc --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
    if [ "$ready_pods" -gt 0 ]; then
        print_success "✓ System pods are running ($ready_pods pods)"
    else
        print_warning "⚠ System pods may still be starting up"
    fi
    
    # Test basic API functionality
    if kubectl get namespaces --context kind-spacelift-poc >/dev/null 2>&1; then
        print_success "✓ Kubernetes API is responsive"
    else
        print_error "✗ Kubernetes API is not responsive"
        return 1
    fi
    
    return 0
}

# Function to display cluster info
show_cluster_info() {
    echo -e "\n${GREEN}🎉 Kind cluster 'spacelift-poc' is ready!${NC}\n"
    
    echo -e "${BLUE}Cluster Information:${NC}"
    echo "  - Cluster name: spacelift-poc"
    echo "  - Context: kind-spacelift-poc"
    echo "  - Kubernetes version: $(kubectl version --context kind-spacelift-poc --short --client 2>/dev/null | grep -E "Client|Server" || echo "Unknown")"
    
    echo -e "\n${BLUE}Exposed Ports:${NC}"
    echo "  - HTTP: localhost:8080 -> cluster:80"
    echo "  - HTTPS: localhost:8443 -> cluster:443"
    echo "  - Custom: localhost:8000 -> cluster:8000"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  - Use cluster: kubectl --context kind-spacelift-poc <command>"
    echo "  - Set default context: kubectl config use-context kind-spacelift-poc"
    echo "  - View cluster info: kubectl cluster-info --context kind-spacelift-poc"
    echo "  - List nodes: kubectl get nodes --context kind-spacelift-poc"
    echo "  - Delete cluster: kind delete cluster --name spacelift-poc"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "  - Install Spacelift operator in this cluster"
    echo "  - Create Spacelift worker pool resources"
    echo "  - Deploy sample applications for testing"
}

# Main execution
main() {
    print_status "Setting up Kind cluster for Spacelift POC..."
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    check_command "kind"
    check_command "kubectl"
    print_success "All prerequisites are installed"
    
    # Check if Docker is running
    check_docker_running
    
    # Check if cluster already exists
    if kind get clusters | grep -q "spacelift-poc"; then
        print_warning "Cluster 'spacelift-poc' already exists"
        if validate_cluster; then
            print_success "Existing cluster is healthy"
            show_cluster_info
            exit 0
        else
            print_warning "Existing cluster is unhealthy. Recreating..."
            print_status "Deleting existing cluster..."
            kind delete cluster --name spacelift-poc
        fi
    fi
    
    # Create the cluster
    print_status "Creating Kind cluster with configuration..."
    if [ -f "../kind-config.yaml" ]; then
        kind create cluster --config ../kind-config.yaml
    elif [ -f "kind-config.yaml" ]; then
        kind create cluster --config kind-config.yaml
    else
        print_error "kind-config.yaml not found. Please run this script from the project root or scripts directory."
        exit 1
    fi
    
    # Wait for cluster to be ready
    wait_for_cluster
    
    # Validate cluster
    if validate_cluster; then
        print_success "Cluster validation completed successfully"
    else
        print_error "Cluster validation failed"
        exit 1
    fi
    
    # Show cluster information
    show_cluster_info
}

# Handle script interruption
setup_interrupt_handler "Setup"

# Run main function
main "$@"