variable "environment_name" {
  description = "Name of the environment"
  type        = string
}

# ---------------------------------------------------
#
#      Managed in AWS Parameter Store
#
# ----------------------------------------------------

data "aws_ssm_parameter" "db_username" {
  name = "/common/mock_api_db/POSTGRES_USER"
}
