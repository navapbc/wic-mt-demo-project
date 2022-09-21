# generates a secure password randomly

# when 176 is merged:
# update: common/mock_api_db/POSTGRES_PASSWORD in actual parameter store to prevent conflicts
# update: what the rds setup considers a password
# update: add updated auth token to ecs task

resource "random_password" "random_db_password" {
  length           = 48
  special          = true
  min_special      = 6
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "random_db_password" {
  name  = "common/mock_api_db/POSTGRES_PASSWORD"
  type  = "SecureString"
  value = random_password.random_db_password.result
}

# Creates an API key we can use to auth containers with
resource "random_password" "random_api_key" {
  length           = 16
  special          = true
  min_special      = 6
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
resource "aws_ssm_parameter" "random_api_key" {
  name  = "common/mock_api_db/API_AUTH_TOKEN"
  type  = "SecureString"
  value = random_password.random_api_key.result
}