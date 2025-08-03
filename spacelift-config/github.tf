variable "github_token" {
    description = "GitHub personal access token for authentication"
    type        = string
  sensitive = true
}

variable "github_organization" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
  default     = "POC"
}

# Create a context for GitHub authentication
resource "spacelift_context" "github_auth" {
  name        = "github-auth"
  description = "GitHub authentication for blueprint commit operations"
  space_id    = spacelift_space.poc_space.id

  labels = [
    "provider:github",
    "purpose:authentication"
  ]
}

# GitHub token environment variable (will need to be set manually)
resource "spacelift_environment_variable" "github_token" {
  context_id = spacelift_context.github_auth.id
  name       = "TF_VAR_github_token"
  value      = var.github_token
  write_only = true
}

# GitHub organization environment variable
resource "spacelift_environment_variable" "github_organization" {
  context_id = spacelift_context.github_auth.id
  name       = "TF_VAR_github_organization"
  value      = var.github_organization
  write_only = false
}

# GitHub repository environment variable
resource "spacelift_environment_variable" "github_repository" {
  context_id = spacelift_context.github_auth.id
  name       = "TF_VAR_github_repository"
  value      = var.github_repository
  write_only = false
}