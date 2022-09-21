# generates a secure password randomly

# when 176 is merged:
# update: common/mock_api_db/POSTGRES_PASSWORD in actual parameter store to prevent conflicts
# update: what the rds setup considers a password

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
