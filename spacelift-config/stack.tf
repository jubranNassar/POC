resource "spacelift_stack" "s3_bucket_management" {
  name                    = "S3 Bucket Management"
  branch                  = "main"
  space_id                = spacelift_space.poc_space.id
  repository              = "POC"
  project_root            = "stacks/commit_to_repo/s3"
  autodeploy              = true
  worker_pool_id          = spacelift_worker_pool.poc_pool.id
  terraform_workflow_tool = "OPEN_TOFU"
  terraform_version       = "1.10.2"
  
  labels = [
    "environment:poc",
    "purpose:blueprint-execution"
  ]
}

resource "spacelift_aws_integration_attachment" "s3_bucket_management" {
  stack_id       = spacelift_stack.s3_bucket_management.id
  integration_id = spacelift_aws_integration.localstack.id
}

# Attach GitHub authentication context to the S3 bucket management stack
resource "spacelift_context_attachment" "s3_github_auth" {
  context_id = spacelift_context.github_auth.id
  stack_id   = spacelift_stack.s3_bucket_management.id
  priority   = 0
}

# Attach AWS integration to the stack
resource "spacelift_aws_integration_attachment" "s3_bucket_aws" {
  integration_id = spacelift_aws_integration.localstack.id
  stack_id       = spacelift_stack.s3_bucket_management.id
  read           = true
  write          = true
}

resource "spacelift_context_attachment" "s3_bucket_localstack" {
  context_id = spacelift_context.localstack_config.id
  stack_id   = spacelift_stack.s3_bucket_management.id
  priority   = 0
}
