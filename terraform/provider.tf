terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Descomentar para usar S3 backend (state remoto)
  # backend "s3" {
  #   bucket = "ocai-terraform-state"
  #   key    = "lambda/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "OCAI Medical"
      ManagedBy = "Terraform"
    }
  }
}
