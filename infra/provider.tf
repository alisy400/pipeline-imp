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


terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-shaw0404"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
  }
}
