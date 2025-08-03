variable "bucket_name" {
  description = "Base name for the S3 bucket (will be suffixed with random string)"
  type        = string
  default     = "spacelift-poc-bucket"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must contain only lowercase letters, numbers, and hyphens, and must not start or end with a hyphen."
  }
}

variable "aws_region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "enable_versioning" {
  description = "Enable versioning on the S3 bucket"
  type        = bool
  default     = true
}