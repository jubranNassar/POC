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
            "helm")
                echo "Installation guides:"
                echo "  - macOS: brew install helm"
                echo "  - Linux: https://helm.sh/docs/intro/install/"
                echo "  - Windows: choco install kubernetes-helm"
                ;;
        esac
        exit 1
    fi
}

# Function to wait for operator pods to be ready
wait_for_operator_pods() {
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for Spacelift operator pods to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        local ready_pods
        ready_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
        
        if [ "$ready_pods" -gt 0 ]; then
            local total_pods
            total_pods=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc --no-headers 2>/dev/null | wc -l || echo "0")
            
            if [ "$ready_pods" -eq "$total_pods" ] && [ "$ready_pods" -gt 0 ]; then
                print_success "All operator pods are ready! ($ready_pods/$total_pods)"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_error "Operator pods failed to become ready after $((max_attempts * 2)) seconds"
    kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc || true
    return 1
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
    if ! kubectl cluster-info --context kind-spacelift-poc >/dev/null 2>&1; then
        print_error "Kind cluster 'spacelift-poc' is not running or accessible"
        print_error "Please run ./setup.sh to start the cluster"
        exit 1
    fi
    print_success "Kind cluster is accessible"
    
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
    
    # Show operator information
    show_operator_info
}

# Handle script interruption
trap 'print_error "Installation interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"