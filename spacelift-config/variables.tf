variable "worker_pool_name" {
  description = "Name for the worker pool"
  type        = string
  default     = "poc-local-k8s-pool"
}

variable "space_name" {
  description = "Name for the POC space"
  type        = string
  default     = "POC Environment"
}

variable "csr_file_path" {
  description = "Path to the CSR file"
  type        = string
  default     = "../certs/spacelift.csr"
}