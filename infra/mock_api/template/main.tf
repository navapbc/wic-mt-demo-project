# this file should contain information about tf versions and required providers

terraform {
  required_version = "1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16.0"
    }
  }
}

module "constants" {
  source = "../constants"
}

provider "aws" {
  region  = "us-east-1"
  profile = "wic-mt"
  default_tags {
    tags = merge(
      module.constants.api_tags, {
        environment = var.environment_name
    })
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


# define env vars here!

# Things you need for each environment:
# logging per env

# may need to create these roles for auth
# prod-wic-dev role
# nonprod-wic-dev role
