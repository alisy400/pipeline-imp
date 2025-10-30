terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.4"
}

provider "aws" {
  region = var.aws_region
}


# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks-infra/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#   }
# }
