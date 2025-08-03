# Spacelift S3 Bucket Blueprint

A GitOps-driven workflow for automated S3 bucket creation using Spacelift. Key features include:

- Self-service S3 bucket generation
- Automatic GitHub configuration commits
- Flexible tagging options (simple and complex)
- Scheduled stack cleanup after 1 hour

## Architecture

The workflow follows this pattern:
"Spacelift Blueprint" → "S3 Generation Stack" → "GitHub Repository (Generated .tf)"

## Usage

Users can create S3 buckets by providing:
- Bucket name (required)
- Optional simple or complex tags

The blueprint generates Terraform configurations using the "thoughtbot/terraform-s3-bucket" module, with environment variables automatically set for bucket details and user information.

## Customization

Customization is possible through the S3 template file, and the system supports troubleshooting for GitHub authentication, worker pool configuration, and AWS integration.