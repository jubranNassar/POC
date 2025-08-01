#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"


# Function to generate certificates
generate_certificates() {
    local cert_dir="certs"
    
    # Create certs directory if it doesn't exist
    create_secure_directory "$cert_dir" 755
    
    # Check if certificates already exist
    if [ -f "$cert_dir/spacelift.key" ] && [ -f "$cert_dir/spacelift.csr" ]; then
        print_warning "Certificates already exist in $cert_dir/"
        echo "Existing files:"
        echo "  - $cert_dir/spacelift.key (private key)"
        echo "  - $cert_dir/spacelift.csr (certificate signing request)"
        echo ""
        if ! confirm_action "Do you want to regenerate them"; then
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
setup_interrupt_handler "Certificate generation"

# Run main function
main "$@"