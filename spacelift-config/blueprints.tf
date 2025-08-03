# Blueprint configuration
locals {
  blueprint    = templatefile("${path.module}/blueprint/blueprint.yaml", {
    worker_pool_id = spacelift_worker_pool.poc_pool.id,
    poc_space_id = spacelift_space.poc_space.id,
  })
  blueprint_pr = templatefile("${path.module}/blueprint/blueprint_pr.yaml", {
    worker_pool_id = spacelift_worker_pool.poc_pool.id
    poc_space_id = spacelift_space.poc_space.id,
  })
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