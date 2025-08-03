# Create S3 bucket stack
resource "spacelift_stack" "s3_bucket" {
  name        = "s3-bucket-poc"
  description = "S3 bucket deployment to LocalStack for POC demonstration"
  repository  = "POC"
  branch      = "main"
  
  # Point to the s3-bucket directory
  project_root = "stacks/s3-bucket"
  
  # Use the POC space
  space_id = spacelift_space.poc_space.id
  
  # Use the local worker pool
  worker_pool_id = spacelift_worker_pool.poc_pool.id
  
  # Auto-deploy changes
  autodeploy = true
  
  # Auto-retry failed runs
  autoretry = false
  
  labels = [
    "infrastructure:s3",
    "environment:poc",
    "provider:aws",
    "demo:true"
  ]
}

# Attach LocalStack configuration context to the stack
resource "spacelift_context_attachment" "s3_bucket_localstack" {
  context_id = spacelift_context.localstack_config.id
  stack_id   = spacelift_stack.s3_bucket.id
  priority   = 0
}

# Attach AWS integration to the stack
resource "spacelift_aws_integration_attachment" "s3_bucket_aws" {
  integration_id = spacelift_aws_integration.localstack.id
  stack_id       = spacelift_stack.s3_bucket.id
  read           = true
  write          = true
}

output "s3_stack_id" {
  description = "The ID of the S3 bucket stack"
  value       = spacelift_stack.s3_bucket.id
}