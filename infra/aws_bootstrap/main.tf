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
locals {
  # enforce region where infrastructure should be deployed
  region = "us-east-1"
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
  region  = local.region
  profile = "wic-mt"
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {

}
# Internal QA testing next week
# spin up tmp ecs service/task that runs the image with the QA tag
# one more env_var (api_host)
# screener needs to know how to connect to mock api -> service name vs task name
# more secrets?? (screener may need mock api token)
# talk to Connor about DNS records and CNAME