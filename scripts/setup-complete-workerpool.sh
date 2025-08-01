#!/bin/bash
set -e

# Source common library functions
source "$(dirname "$0")/lib/common.sh"

print_workerpool_header() {
    print_header "Complete Worker Pool Setup"
}

# Main execution
main() {
    print_workerpool_header
    
    echo "This script will guide you through setting up a complete Spacelift worker pool:"
    echo "1. Generate certificates and CSR"
    echo "2. Create Spacelift resources (worker pool, space, context)"
    echo "3. Create WorkerPool object in Kubernetes"
    echo ""
    
    read -p "Continue with worker pool setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi
    
    # Step 1: Generate certificates
    show_progress 1 3 "Generate Worker Pool Certificates"
    run_script "./scripts/generate-worker-pool-certs.sh" "Certificate generation"
    
    echo ""
    print_status "Certificates generated successfully!"
    print_status "Next, we'll create the Spacelift resources. You'll need to login to your Spacelift account."
    echo ""
    read -p "Press Enter to continue with Spacelift setup..."
    
    # Step 2: Create Spacelift resources
    show_progress 2 3 "Create Spacelift Resources"
    run_script "./scripts/setup-spacelift-resources.sh" "Spacelift resources creation"
    
    echo ""
    print_status "Spacelift resources created successfully!"
    print_status "Finally, we'll create the WorkerPool object in your Kubernetes cluster."
    echo ""
    read -p "Press Enter to continue with Kubernetes setup..."
    
    # Step 3: Create WorkerPool in Kubernetes
    show_progress 3 3 "Create WorkerPool in Kubernetes"
    run_script "./scripts/create-workerpool-k8s.sh" "Kubernetes WorkerPool creation"
    
    # Show final status
    echo -e "\n${GREEN}🎉 Complete Worker Pool Setup Finished!${NC}\n"
    
    echo -e "${BLUE}What was created:${NC}"
    echo "✅ SSL certificates and CSR"
    echo "✅ Spacelift worker pool, space, and context"
    echo "✅ Kubernetes WorkerPool object and secrets"
    echo "✅ Worker pods running in Kind cluster"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Verify worker pool shows as 'healthy' in Spacelift UI"
    echo "2. Create Spacelift stacks that use the 'poc-local-k8s-pool' worker pool"
    echo "3. Deploy sample infrastructure targeting LocalStack"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "  - Check workers: kubectl get pods -n spacelift-worker-controller-system --context kind-spacelift-poc"
    echo "  - Worker logs: kubectl logs -n spacelift-worker-controller-system --context kind-spacelift-poc -l app.kubernetes.io/name=spacelift-worker"
    echo "  - Spacelift CLI: spacectl stack list"
    
    echo -e "\n${YELLOW}Note:${NC}"
    echo "Your worker pool is now ready to execute Spacelift runs locally!"
    echo "Infrastructure will be deployed to LocalStack at http://localhost:4566"
}

# Handle script interruption
trap 'print_error "Worker pool setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"