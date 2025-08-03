#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"

# Function to check if IMDS mock deployment exists
check_imds_mock_exists() {
    kubectl get deployment imds-mock -n spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1
}

# Function to check if IMDS mock is ready
check_imds_mock_ready() {
    local ready_replicas
    ready_replicas=$(kubectl get deployment imds-mock -n spacelift-worker-controller-system --context kind-spacelift-poc -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    [ "$ready_replicas" = "1" ]
}

# Function to wait for IMDS mock to be ready
wait_for_imds_mock() {
    if wait_with_timeout "check_imds_mock_ready" 60 2 "IMDS mock deployment to be ready"; then
        return 0
    else
        print_error "IMDS mock deployment failed to become ready"
        print_error "Check the logs with: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app=imds-mock"
        return 1
    fi
}

# Function to validate IMDS mock functionality
validate_imds_mock() {
    print_status "Validating IMDS mock functionality..."
    
    # Get the IMDS service ClusterIP for testing
    local imds_service_ip
    imds_service_ip=$(kubectl get service imds-mock -n spacelift-worker-controller-system --context kind-spacelift-poc -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    
    if [ -z "$imds_service_ip" ]; then
        print_error "Could not get IMDS service ClusterIP"
        return 1
    fi
    
    # Create a temporary test pod with curl
    print_status "Creating temporary test pod..."
    kubectl run imds-test --image=curlimages/curl --context kind-spacelift-poc --command -- sleep 10 >/dev/null 2>&1
    
    # Wait for test pod to be ready
    if kubectl wait --for=condition=ready pod/imds-test --context kind-spacelift-poc --timeout=30s >/dev/null 2>&1; then
        # Test the token endpoint
        if kubectl exec imds-test --context kind-spacelift-poc -- curl -s "http://$imds_service_ip/latest/api/token" | grep -q "mock-token"; then
            print_success "✓ IMDS token endpoint is working"
        else
            print_error "✗ IMDS token endpoint test failed"
            kubectl delete pod imds-test --context kind-spacelift-poc >/dev/null 2>&1 || true
            return 1
        fi
        
        # Test the credentials endpoint
        if kubectl exec imds-test --context kind-spacelift-poc -- curl -s "http://$imds_service_ip/latest/meta-data/iam/security-credentials/SpaceliftAdminRole" | grep -q "AccessKeyId"; then
            print_success "✓ IMDS credentials endpoint is working"
        else
            print_error "✗ IMDS credentials endpoint test failed"
            kubectl delete pod imds-test --context kind-spacelift-poc >/dev/null 2>&1 || true
            return 1
        fi
        
        # Clean up test pod
        kubectl delete pod imds-test --context kind-spacelift-poc >/dev/null 2>&1 || true
    else
        print_error "Test pod failed to start"
        kubectl delete pod imds-test --context kind-spacelift-poc >/dev/null 2>&1 || true
        return 1
    fi
    
    return 0
}

# Main function
deploy_imds_mock() {
    print_header "Deploying IMDS Mock for Spacelift Workers"
    
    # Check if IMDS mock already exists and is ready
    if check_imds_mock_exists; then
        print_warning "IMDS mock deployment already exists"
        if check_imds_mock_ready; then
            print_success "IMDS mock is already running and ready"
            if validate_imds_mock; then
                print_success "IMDS mock validation completed successfully"
                return 0
            else
                print_warning "IMDS mock validation failed, redeploying..."
                kubectl delete -f k8s-imds-mock.yaml --context kind-spacelift-poc || true
                sleep 5
            fi
        else
            print_warning "IMDS mock exists but is not ready, redeploying..."
            kubectl delete -f k8s-imds-mock.yaml --context kind-spacelift-poc || true
            sleep 5
        fi
    fi
    
    # Deploy IMDS mock
    print_status "Deploying IMDS mock service..."
    kubectl apply -f k8s-imds-mock.yaml --context kind-spacelift-poc
    
    # Wait for IMDS mock to be ready
    if ! wait_for_imds_mock; then
        exit 1
    fi
    
    print_success "IMDS mock deployment is ready"
    
    # Get the IMDS service ClusterIP for reference
    local imds_service_ip
    imds_service_ip=$(kubectl get service imds-mock -n spacelift-worker-controller-system --context kind-spacelift-poc -o jsonpath='{.spec.clusterIP}')
    
    if [ -z "$imds_service_ip" ]; then
        print_error "Could not get IMDS service ClusterIP"
        return 1
    fi
    
    print_status "IMDS service ClusterIP: $imds_service_ip"
    print_status "Note: Worker pools will use hostAliases to route 169.254.169.254 to this IP"
    
    # Validate IMDS mock functionality
    if validate_imds_mock; then
        print_success "IMDS mock validation completed successfully"
    else
        print_error "IMDS mock validation failed"
        return 1
    fi
    
    print_success "✓ IMDS mock deployment completed successfully"
    echo "  - Mock IMDS service is running and responding at $imds_service_ip"
    echo "  - Service provides AWS credentials and metadata endpoints"
    echo "  - Spacelift workers will use hostAliases to access 169.254.169.254"
    
    return 0
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_imds_mock "$@"
fi