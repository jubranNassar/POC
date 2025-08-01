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

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}  Spacelift POC Cleanup Script${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

# Main execution
main() {
    print_header
    
    print_status "Stopping and removing LocalStack containers..."
    
    # Stop and remove containers
    if docker-compose down; then
        print_success "LocalStack containers stopped and removed"
    else
        print_warning "Some containers may have already been stopped"
    fi
    
    # Remove any leftover LocalStack data
    if [ -d "./localstack-data" ]; then
        print_status "Removing LocalStack data directory..."
        rm -rf ./localstack-data
        print_success "LocalStack data directory removed"
    fi
    
    # Check if any LocalStack processes are still running
    if docker ps | grep -q "localstack"; then
        print_warning "Some LocalStack containers are still running"
        docker ps | grep "localstack"
    else
        print_success "No LocalStack containers are running"
    fi
    
    # Clean up Spacelift operator (if Helm is available)
    print_status "Cleaning up Spacelift operator..."
    if command -v helm &> /dev/null && command -v kubectl &> /dev/null; then
        if kubectl cluster-info --context kind-spacelift-poc >/dev/null 2>&1; then
            if helm list -n spacelift-worker-controller-system --kube-context kind-spacelift-poc | grep -q "spacelift-workerpool-controller"; then
                print_status "Uninstalling Spacelift operator..."
                helm uninstall spacelift-workerpool-controller -n spacelift-worker-controller-system --kube-context kind-spacelift-poc || true
                print_success "Spacelift operator uninstalled"
            else
                print_success "No Spacelift operator found"
            fi
        else
            print_success "Kind cluster not accessible, skipping operator cleanup"
        fi
    else
        print_warning "Helm or kubectl not available, skipping operator cleanup"
    fi
    
    # Clean up Kind cluster
    print_status "Cleaning up Kind cluster..."
    if command -v kind &> /dev/null; then
        if kind get clusters | grep -q "spacelift-poc"; then
            print_status "Deleting Kind cluster 'spacelift-poc'..."
            kind delete cluster --name spacelift-poc
            print_success "Kind cluster deleted"
        else
            print_success "No Kind cluster 'spacelift-poc' found"
        fi
    else
        print_warning "Kind not installed, skipping cluster cleanup"
    fi
    
    # Clean up certificates and Terraform files (optional)
    if [ -d "certs" ] || [ -d "spacelift-config/.terraform" ]; then
        echo ""
        read -p "Do you want to clean up certificates and Terraform files? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleaning up certificates and Terraform files..."
            
            if [ -d "certs" ]; then
                rm -rf certs
                print_success "Certificates directory removed"
            fi
            
            if [ -d "spacelift-config/.terraform" ]; then
                rm -rf spacelift-config/.terraform*
                rm -f spacelift-config/tfplan
                print_success "Terraform files cleaned up"
            fi
        else
            print_status "Keeping certificates and Terraform files"
        fi
    fi
    
    print_success "✨ Cleanup completed successfully!"
    echo -e "\n${BLUE}Your system is now clean and ready for a fresh start.${NC}"
    echo -e "Run ${YELLOW}./setup.sh${NC} anytime to start the POC environment again."
}

# Handle script interruption
trap 'print_error "Cleanup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"