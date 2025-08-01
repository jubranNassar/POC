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
            "openssl")
                echo "Installation guides:"
                echo "  - macOS: Usually pre-installed, or brew install openssl"
                echo "  - Linux: sudo apt-get install openssl (Ubuntu/Debian) or yum install openssl (RHEL/CentOS)"
                echo "  - Windows: Use WSL or install OpenSSL for Windows"
                ;;
        esac
        exit 1
    fi
}

# Function to generate certificates
generate_certificates() {
    local cert_dir="certs"
    
    # Create certs directory if it doesn't exist
    if [ ! -d "$cert_dir" ]; then
        mkdir -p "$cert_dir"
        print_status "Created $cert_dir directory"
    fi
    
    # Check if certificates already exist
    if [ -f "$cert_dir/spacelift.key" ] && [ -f "$cert_dir/spacelift.csr" ]; then
        print_warning "Certificates already exist in $cert_dir/"
        echo "Existing files:"
        echo "  - $cert_dir/spacelift.key (private key)"
        echo "  - $cert_dir/spacelift.csr (certificate signing request)"
        echo ""
        read -p "Do you want to regenerate them? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Using existing certificates"
            return 0
        fi
        print_status "Regenerating certificates..."
    fi
    
    # Generate private key and CSR
    print_status "Generating private key and Certificate Signing Request..."
    
    # Create CSR with minimal required information
    openssl req -new -newkey rsa:4096 -nodes -keyout "$cert_dir/spacelift.key" -out "$cert_dir/spacelift.csr" \
        -subj "/C=US/ST=Local/L=Local/O=Spacelift POC/OU=Worker Pool/CN=spacelift-poc-worker-pool"
    
    print_success "Certificates generated successfully!"
    echo "Generated files:"
    echo "  - $cert_dir/spacelift.key (private key - keep this secure!)"
    echo "  - $cert_dir/spacelift.csr (certificate signing request - upload to Spacelift)"
}

# Function to display next steps
show_next_steps() {
    echo -e "\n${GREEN}🎉 Worker Pool Certificates Generated!${NC}\n"
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Upload the CSR to Spacelift:"
    echo "   - Go to your Spacelift account"
    echo "   - Navigate to 'Worker pools'"
    echo "   - Click 'Create worker pool'"
    echo "   - Upload the file: certs/spacelift.csr"
    echo "   - Give it a name like 'poc-local-pool'"
    echo "   - Download the worker pool configuration file"
    echo ""
    echo "2. Save the configuration:"
    echo "   - Save the downloaded config as: certs/spacelift-workerpool.config"
    echo ""
    echo "3. Run the WorkerPool setup:"
    echo "   - ./scripts/create-workerpool-k8s.sh"
    
    echo -e "\n${BLUE}Files Generated:${NC}"
    echo "  - certs/spacelift.key (private key)"
    echo "  - certs/spacelift.csr (upload to Spacelift)"
    
    echo -e "\n${YELLOW}Security Note:${NC}"
    echo "The private key (spacelift.key) should be kept secure and not committed to version control."
}

# Main execution
main() {
    print_status "Generating Spacelift Worker Pool Certificates..."
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    check_command "openssl"
    print_success "OpenSSL is available"
    
    # Generate certificates
    generate_certificates
    
    # Show next steps
    show_next_steps
}

# Handle script interruption
trap 'print_error "Certificate generation interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"