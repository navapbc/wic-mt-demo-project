locals {
  environment_name = "prod"
}

provider "aws" {
  region  = "us-east-1"
  profile = "wic-mt"
}
# s3 backend moved so that terraform won't ignore it

terraform {
  required_version = "1.2.0"

  backend "s3" {
    bucket         = "wic-mt-tf-state"
    key            = "terraform/mock_api/prod.tfstate"
    region         = "us-east-1"
    encrypt        = "true"
    dynamodb_table = "wic_terraform_locks"
    profile        = "wic-mt" # may need to rethink this; no profile defaults to env variables
  }
}

module "template" {
  source           = "../../template"
  environment_name = local.environment_name
}
