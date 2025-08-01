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
        exit 1
    fi
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check required commands
    check_command "kubectl"
    check_command "base64"
    
    # Check if Kind cluster is accessible
    if ! kubectl cluster-info --context kind-spacelift-poc >/dev/null 2>&1; then
        print_error "Kind cluster 'spacelift-poc' is not accessible"
        print_error "Please run ./setup.sh to ensure the cluster is running"
        exit 1
    fi
    
    # Check if Spacelift operator is installed
    if ! kubectl get namespace spacelift-worker-controller-system --context kind-spacelift-poc >/dev/null 2>&1; then
        print_error "Spacelift operator namespace not found"
        print_error "Please run ./setup.sh to install the Spacelift operator"
        exit 1
    fi
    
    # Check if required files exist
    if [ ! -f "certs/spacelift.key" ]; then
        print_error "Private key not found: certs/spacelift.key"
        print_error "Please run ./scripts/generate-worker-pool-certs.sh first"
        exit 1
    fi
    
    if [ ! -f "certs/spacelift-workerpool.config" ]; then
        print_error "Worker pool config not found: certs/spacelift-workerpool.config"
        echo ""
        echo "Steps to get this file:"
        echo "1. Go to your Spacelift account"
        echo "2. Navigate to 'Worker pools'"
        echo "3. Create a worker pool using certs/spacelift.csr"
        echo "4. Download the configuration and save as certs/spacelift-workerpool.config"
        exit 1
    fi
    
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
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
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
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
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

# Function to wait for workers to be ready
wait_for_workers() {
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for worker pods to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        local ready_workers
        ready_workers=$(kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
        
        if [ "$ready_workers" -gt 0 ]; then
            print_success "Worker pods are ready! ($ready_workers running)"
            kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_warning "Worker pods not ready after $((max_attempts * 2)) seconds"
    print_status "Current pod status:"
    kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker || true
    return 1
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
    
    # Wait for workers to be ready (optional)
    wait_for_workers || print_warning "Continuing despite worker pods not being ready yet"
    
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
trap 'print_error "WorkerPool setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"