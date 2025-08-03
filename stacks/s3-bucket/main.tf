terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # LocalStack configuration will be provided via environment variables
  # AWS_ENDPOINT_URL, AWS_STS_ENDPOINT_URL, etc. from Spacelift context
  
  # Skip credentials validation and metadata API calls for LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  # Force path-style requests for LocalStack compatibility
  s3_use_path_style = true
}

# Create S3 bucket with random suffix for uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "poc_bucket" {
  bucket = "${var.bucket_name}-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = var.bucket_name
    Environment = "poc"
    Project     = "spacelift-poc"
    ManagedBy   = "spacelift"
  }
}

# Configure bucket versioning
resource "aws_s3_bucket_versioning" "poc_bucket_versioning" {
  bucket = aws_s3_bucket.poc_bucket.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Configure bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "poc_bucket_encryption" {
  bucket = aws_s3_bucket.poc_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "poc_bucket_pab" {
  bucket = aws_s3_bucket.poc_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create a sample object
resource "aws_s3_object" "sample_file" {
  bucket = aws_s3_bucket.poc_bucket.id
  key    = "sample-files/welcome.txt"
  content = "Hello from Spacelift POC! This S3 bucket was created using LocalStack and deployed via Spacelift."
  
  tags = {
    Name        = "sample-welcome-file"
    Environment = "poc"
    CreatedBy   = "spacelift"
  }
}

# Create a folder structure
resource "aws_s3_object" "logs_folder" {
  bucket = aws_s3_bucket.poc_bucket.id
  key    = "logs/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "data_folder" {
  bucket = aws_s3_bucket.poc_bucket.id
  key    = "data/"
  content_type = "application/x-directory"
}