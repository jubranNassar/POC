variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "bucket_tags_simple" {
  description = "Tags to assign to the S3 bucket"
  type        = string
  default     = ""
}

variable "bucket_tags_complex" {
  description = "Tags to assign to the S3 bucket"
  type        = map(string)
  default     = {}
}

variable "github_token" {
  description = "GitHub token with permissions to commit to the repository"
  type        = string
}

variable "github_organization" {
  description = "GitHub organization where the repository is located"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository where the S3 bucket configuration will be committed"
  type        = string
  default     = "s3"
}

variable "username" {
  description = "Username of the user who triggered the run"
  type        = string
}

variable "user_login" {
  description = "Login of the user who triggered the run"
  type        = string
}

variable "branch" {
  description = "Branch of the GitHub repository to commit to"
  type        = string
  default     = "main"
}