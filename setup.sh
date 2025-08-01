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
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  Complete Spacelift POC Setup${NC}"
    echo -e "${BLUE}========================================${NC}\n"
    echo "This will set up a complete Spacelift POC environment:"
    echo "• LocalStack (AWS services)"
    echo "• Kind cluster (Kubernetes)"
    echo "• Spacelift operator"
    echo "• Complete worker pool (ready to run stacks)"
    echo ""
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install $1 and try again."
        echo "Installation guides:"
        case "$1" in
            "docker")
                echo "  - macOS: https://docs.docker.com/desktop/install/mac-install/"
                echo "  - Linux: https://docs.docker.com/engine/install/"
                echo "  - Windows: https://docs.docker.com/desktop/install/windows-install/"
                ;;
            "docker-compose")
                echo "  - Usually included with Docker Desktop"
                echo "  - Linux: https://docs.docker.com/compose/install/"
                ;;
            "kind")
                echo "  - macOS: brew install kind"
                echo "  - Linux: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
                echo "  - Windows: choco install kind"
                ;;
            "kubectl")
                echo "  - macOS: brew install kubectl"
                echo "  - Linux: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
                echo "  - Windows: choco install kubernetes-cli"
                ;;
            "helm")
                echo "  - macOS: brew install helm"
                echo "  - Linux: https://helm.sh/docs/intro/install/"
                echo "  - Windows: choco install kubernetes-helm"
                ;;
            "terraform")
                echo "  - macOS: brew install terraform"
                echo "  - Linux: https://learn.hashicorp.com/tutorials/terraform/install-cli"
                echo "  - Windows: choco install terraform"
                ;;
            "spacectl")
                echo "  - macOS: brew install spacelift-io/spacelift/spacectl"
                echo "  - Linux: https://github.com/spacelift-io/spacectl#installation"
                echo "  - Windows: https://github.com/spacelift-io/spacectl#installation"
                ;;
        esac
        exit 1
    fi
}

# Function to wait for LocalStack to be healthy
wait_for_localstack() {
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for LocalStack to become healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:4566/_localstack/health >/dev/null 2>&1; then
            print_success "LocalStack is healthy!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_error "LocalStack failed to become healthy after $((max_attempts * 2)) seconds"
    print_error "Check the logs with: docker-compose logs localstack"
    exit 1
}

# Function to validate LocalStack services
validate_localstack() {
    print_status "Validating LocalStack services..."
    
    # Check if health endpoint returns expected services
    local health_response
    health_response=$(curl -s http://localhost:4566/_localstack/health)
    
    if echo "$health_response" | grep -q '"s3": "available"' || echo "$health_response" | grep -q '"s3": "running"'; then
        print_success "✓ S3 service is available"
    else
        print_error "✗ S3 service is not available"
        return 1
    fi
    
    if echo "$health_response" | grep -q '"lambda": "available"'; then
        print_success "✓ Lambda service is available"
    else
        print_error "✗ Lambda service is not available"
        return 1
    fi
    
    if echo "$health_response" | grep -q '"dynamodb": "available"'; then
        print_success "✓ DynamoDB service is available"
    else
        print_error "✗ DynamoDB service is not available"
        return 1
    fi
    
    # Test S3 API by creating a test bucket
    if curl -s -X PUT "http://localhost:4566/spacelift-poc-validation-bucket" >/dev/null 2>&1; then
        print_success "✓ S3 API is working (test bucket created)"
        # Clean up test bucket
        curl -s -X DELETE "http://localhost:4566/spacelift-poc-validation-bucket" >/dev/null 2>&1
    else
        print_error "✗ S3 API test failed"
        return 1
    fi
    
    return 0
}

# Function to display next steps
show_next_steps() {
    echo -e "\n${GREEN}🎉 Complete Spacelift POC Environment is Ready!${NC}"
    echo -e "${GREEN}   Everything is set up and ready to test!${NC}\n"
    
    echo -e "${BLUE}✅ LocalStack (AWS Services):${NC}"
    echo "  - Running at: http://localhost:4566"
    echo "  - AWS credentials: test/test"
    echo "  - Region: us-east-1"
    echo "  - Services: S3, Lambda, DynamoDB, API Gateway, EC2, VPC, IAM, CloudFormation"
    
    echo -e "\n${BLUE}✅ Kind Cluster (Kubernetes):${NC}"
    echo "  - Cluster name: spacelift-poc"
    echo "  - Context: kind-spacelift-poc"
    echo "  - Exposed ports: 8080 (HTTP), 8443 (HTTPS), 8000 (custom)"
    
    echo -e "\n${BLUE}✅ Spacelift Operator:${NC}"
    echo "  - Installed via Helm in spacelift-worker-controller-system namespace"
    echo "  - Ready to manage WorkerPool resources"
    echo "  - CRDs: workerpools.workers.spacelift.io, workers.workers.spacelift.io"
    
    echo -e "\n${BLUE}✅ Spacelift Worker Pool:${NC}"
    echo "  - Worker pool created in your Spacelift account"
    echo "  - Local worker pods running in Kind cluster"
    echo "  - Ready to execute Spacelift runs locally"
    echo "  - Configured with LocalStack AWS credentials"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Create Spacelift stacks using the 'poc-local-k8s-pool' worker pool"
    echo "2. Deploy sample infrastructure stacks to LocalStack"
    echo "3. Test complete Spacelift workflows and governance"
    echo "4. Explore blueprints, policies, and advanced features"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  LocalStack:"
    echo "    - Status: docker-compose ps"
    echo "    - Logs: docker-compose logs localstack"
    echo "    - Test: curl http://localhost:4566/_localstack/health"
    echo ""
    echo "  Kind Cluster:"
    echo "    - Status: kubectl get nodes --context kind-spacelift-poc"
    echo "    - Pods: kubectl get pods --all-namespaces --context kind-spacelift-poc"
    echo "    - Delete: kind delete cluster --name spacelift-poc" 
    echo ""
    echo "  Spacelift Operator:"
    echo "    - Status: kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc"
    echo "    - Logs: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-workerpool-controller"
    echo "    - CRDs: kubectl get crd --context kind-spacelift-poc | grep spacelift"
    echo ""
    echo "  Spacelift Worker Pool:"
    echo "    - Workers: kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker"
    echo "    - Worker Logs: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker"
    echo "    - WorkerPool: kubectl get workerpool -n spacelift-worker-controller-system --context kind-spacelift-poc"
    echo "    - Spacelift CLI: spacectl stack list"
    echo ""
    echo "  Complete Cleanup:"
    echo "    - Run: ./cleanup.sh"
    
    echo -e "\n${YELLOW}Note:${NC} Both LocalStack and Kind data are ephemeral."
    echo "Perfect for clean POC testing every time!"
}

# Main execution
main() {
    print_header
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    check_command "docker"
    check_command "docker-compose"
    check_command "kind"
    check_command "kubectl"
    check_command "helm"
    check_command "terraform"
    check_command "spacectl"
    print_success "All prerequisites are installed"
    
    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker daemon is running"
    
    # Check if LocalStack is already running
    if curl -s http://localhost:4566/_localstack/health >/dev/null 2>&1; then
        print_warning "LocalStack appears to already be running"
        # Give LocalStack a moment to fully start up services
        sleep 5
        if validate_localstack; then
            print_success "LocalStack is already healthy and validated"
            # Still run Kind setup and operator installation, but skip LocalStack setup
            print_status "Setting up Kind cluster..."
            if [ -x "./scripts/setup-kind-cluster.sh" ]; then
                ./scripts/setup-kind-cluster.sh
            else
                print_error "Kind setup script not found or not executable"
                exit 1
            fi
            print_status "Installing Spacelift operator..."
            if [ -x "./scripts/install-spacelift-operator.sh" ]; then
                ./scripts/install-spacelift-operator.sh
            else
                print_error "Spacelift operator install script not found or not executable"
                exit 1
            fi
            print_status "Setting up complete Spacelift worker pool..."
            if [ -x "./scripts/setup-complete-workerpool.sh" ]; then
                ./scripts/setup-complete-workerpool.sh
            else
                print_error "Complete worker pool setup script not found or not executable"
                exit 1
            fi
            show_next_steps
            exit 0
        else
            print_warning "LocalStack is running but not healthy. Restarting..."
            docker-compose down
        fi
    fi
    
    # Start LocalStack
    print_status "Starting LocalStack with Docker Compose..."
    docker-compose up -d
    
    # Wait for LocalStack to be healthy
    wait_for_localstack
    
    # Validate LocalStack services
    if validate_localstack; then
        print_success "LocalStack validation completed successfully"
    else
        print_error "LocalStack validation failed"
        print_error "Check the logs with: docker-compose logs localstack"
        exit 1
    fi
    
    # Setup Kind cluster
    print_status "Setting up Kind cluster..."
    if [ -x "./scripts/setup-kind-cluster.sh" ]; then
        ./scripts/setup-kind-cluster.sh
    else
        print_error "Kind setup script not found or not executable"
        print_error "Please ensure ./scripts/setup-kind-cluster.sh exists and is executable"
        exit 1
    fi
    
    # Install Spacelift operator
    print_status "Installing Spacelift operator..."
    if [ -x "./scripts/install-spacelift-operator.sh" ]; then
        ./scripts/install-spacelift-operator.sh
    else
        print_error "Spacelift operator install script not found or not executable"
        print_error "Please ensure ./scripts/install-spacelift-operator.sh exists and is executable"
        exit 1
    fi
    
    # Setup complete worker pool
    print_status "Setting up complete Spacelift worker pool..."
    if [ -x "./scripts/setup-complete-workerpool.sh" ]; then
        ./scripts/setup-complete-workerpool.sh
    else
        print_error "Complete worker pool setup script not found or not executable"
        print_error "Please ensure ./scripts/setup-complete-workerpool.sh exists and is executable"
        exit 1
    fi
    
    # Show next steps
    show_next_steps
}

# Handle script interruption
trap 'print_error "Setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"