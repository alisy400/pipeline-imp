terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

# For local operations and scripting
provider "local" {}
provider "null" {}

# Optional: Local apply hook to auto-deploy manifests via kubectl
# resource "null_resource" "deploy_to_minikube" {
#   provisioner "local-exec" {
#     command = "kubectl apply -f ../k8s/deployment.yaml && kubectl apply -f ../k8s/service.yaml"
#   }
# }
