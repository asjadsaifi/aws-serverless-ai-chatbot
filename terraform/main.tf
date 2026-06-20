# ============================================================
# Main Terraform configuration
# ============================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region

  # Default tags applied to EVERY resource automatically.
  # This is industry standard — makes cost tracking and auditing easy.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "aws-serverless-chatbot"
    }
  }
}

# Local values reused across multiple files
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
