output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.poc_bucket.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.poc_bucket.arn
}

output "bucket_id" {
  description = "ID of the created S3 bucket"
  value       = aws_s3_bucket.poc_bucket.id
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.poc_bucket.bucket_domain_name
}

output "bucket_region" {
  description = "Region where the S3 bucket is created"
  value       = aws_s3_bucket.poc_bucket.region
}

output "sample_file_key" {
  description = "Key of the sample file created in the bucket"
  value       = aws_s3_object.sample_file.key
}

output "bucket_url" {
  description = "URL of the S3 bucket (LocalStack format)"
  value       = "http://localhost:4566/${aws_s3_bucket.poc_bucket.bucket}"
}

output "sample_file_url" {
  description = "URL of the S3 bucket (LocalStack format)"
  value       = "http://localhost:4566/${aws_s3_bucket.poc_bucket.bucket}/${aws_s3_object.sample_file.key}"
}