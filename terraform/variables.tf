variable "github_token" {
  description = "GitHub PAT with repo scope for Flux bootstrap"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub username or organization"
  type        = string
  default     = "KSiig"
}

variable "repository_name" {
  description = "GitHub repository name"
  type        = string
  default     = "homelab"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the K3s cluster"
  type        = string
  default     = "/tmp/k3s-kubeconfig.yaml"
}
