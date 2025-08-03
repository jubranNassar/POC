locals {
  bts = var.bucket_tags_simple != "" ? split(",", var.bucket_tags_simple) : []
  bucket_tags_simple = { for tag in [
    for v in local.bts : v
  ] : split("=", tag)[0] => split("=", tag)[1] }

  is_pr          = var.branch != "main"
  commit_message = "feat: create S3 bucket ${var.bucket_name}"
}

resource "github_repository_file" "foo" {
  repository     = var.github_repository
  branch         = local.is_pr ? github_branch.this[0].branch : var.branch
  file           = "${var.bucket_name}.tf"
  commit_message = local.commit_message
  commit_author  = var.username
  commit_email   = var.user_login
  content = templatefile("${path.module}/s3.tftpl", {
    bucket_name = var.bucket_name
    bucket_tags = var.bucket_tags_simple != "" ? local.bucket_tags_simple : var.bucket_tags_complex
  })
}

resource "github_branch" "this" {
  count      = local.is_pr ? 1 : 0
  repository = var.github_repository
  branch     = var.branch
}

resource "github_repository_pull_request" "this" {
  count = local.is_pr ? 1 : 0

  base_repository = var.github_repository
  base_ref        = "main"
  head_ref        = github_branch.this[0].branch
  title           = local.commit_message
  body            = "This PR creates an S3 bucket named ${var.bucket_name} with the specified tags."

  depends_on = [
    github_repository_file.foo
  ]
}

locals {
  pr_id = local.is_pr ? github_repository_pull_request.this[0].number : ""
}

output "pr_url" {
  value = "https://github.com"
}