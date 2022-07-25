# this file should contain information about tf versions and required providers

terraform {
  required_version = "1.2.0"

  required_providers {
    aws  = {
      source  = "hashicorp/aws"
      version = "~> 4.16.0" 
    }
  }
}

# dynamodb table to support state locking
resource "aws_dynamodb_table" "tf_state_table" {
  name = "wic_terraform_locks"
  hash_key = "LockID"
  read_capacity = 1
  write_capacity = 1
  attribute {
    name = "LockID"
    type = "S"
  }
}

module "constants" {
  source = "../constants"
}

provider "aws" {
  region = "us-east-1"
  profile = "wic-mt"
  default_tags {
    tags = merge(
      module.constants.screener_tags, {
        environment = var.environment_name
        })
  }
}
data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
  
}
