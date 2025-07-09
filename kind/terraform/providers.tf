terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "kube-agent-demo"
}

variable "kube_agent_image" {
  description = "Docker image for kube-agent"
  type        = string
  default     = "ghcr.io/nkbud/kube-agent:latest"
}

variable "enable_ingress" {
  description = "Enable ingress controller"
  type        = bool
  default     = true
}

# Configure providers
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-${var.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kind-${var.cluster_name}"
  }
}