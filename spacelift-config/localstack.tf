# Create AWS integration for LocalStack with assume role
resource "spacelift_aws_integration" "localstack" {
  name                           = "localstack-integration"
  role_arn                       = "arn:aws:iam::000000000000:role/SpaceliftAdminRole"
  external_id                    = "spacelift"
  generate_credentials_in_worker = true
  space_id                       = spacelift_space.poc_space.id

  labels = [
    "provider:aws",
    "environment:local"
  ]
}

# Create a context for LocalStack-specific configuration
resource "spacelift_context" "localstack_config" {
  name        = "localstack-configuration"
  description = "LocalStack endpoint configuration for AWS services"
  space_id    = spacelift_space.poc_space.id

  labels = [
    "provider:aws",
    "environment:local"
  ]
}

# Add LocalStack endpoint configuration
resource "spacelift_environment_variable" "aws_endpoint" {
  context_id = spacelift_context.localstack_config.id
  name       = "AWS_ENDPOINT_URL"
  value      = "http://host.docker.internal:4566"
  write_only = false
}

# Add specific STS endpoint for LocalStack
resource "spacelift_environment_variable" "aws_sts_endpoint" {
  context_id = spacelift_context.localstack_config.id
  name       = "AWS_STS_ENDPOINT_URL"
  value      = "http://host.docker.internal:4566"
  write_only = false
}

# Add IAM endpoint for LocalStack
resource "spacelift_environment_variable" "aws_iam_endpoint" {
  context_id = spacelift_context.localstack_config.id
  name       = "AWS_IAM_ENDPOINT_URL"
  value      = "http://host.docker.internal:4566"
  write_only = false
}

resource "spacelift_environment_variable" "aws_region" {
  context_id = spacelift_context.localstack_config.id
  name       = "AWS_DEFAULT_REGION"
  value      = "us-east-1"
  write_only = false
}