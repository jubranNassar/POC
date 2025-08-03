# Blueprint configuration
locals {
  blueprint    = file("${path.module}/blueprint/blueprint.yaml")
  blueprint_pr = file("${path.module}/blueprint/blueprint_pr.yaml")
}

resource "spacelift_blueprint" "no_pr_blueprint" {
  name     = "Create S3 Bucket (no PR)"
  space    = spacelift_space.poc_space.id
  state    = "PUBLISHED"
  template = local.blueprint
}

resource "spacelift_blueprint" "pr_blueprint" {
  name     = "Create S3 Bucket (with PR)"
  space    = spacelift_space.poc_space.id
  state    = "PUBLISHED"
  template = local.blueprint_pr
}