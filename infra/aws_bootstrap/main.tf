# this file should contain information about tf versions and required providers
# this module is app and env agnostic

terraform {
  required_version = "1.2.0"

  backend "s3" {
    bucket         = "wic-mt-tf-state"
    key            = "terraform/aws_bootstrap/state.tfstate"
    region         = "us-east-1"
    encrypt        = "true"
    dynamodb_table = "wic_terraform_locks"
    profile        = "wic-mt" # may need to rethink this; no profile defaults to env variables
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16.0"
    }
  }
}

# # dynamodb table to support state locking
resource "aws_dynamodb_table" "tf_state_table" {
  name           = "wic_terraform_locks"
  hash_key       = "LockID"
  read_capacity  = 1
  write_capacity = 1
  attribute {
    name = "LockID"
    type = "S"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "wic-mt"
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {

}
#todo fix tf state
