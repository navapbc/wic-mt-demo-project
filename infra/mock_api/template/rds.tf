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
  name  = "/common/mock_api_db/POSTGRES_PASSWORD"
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
  name  = "/common/mock_api_db/API_AUTH_TOKEN"
  type  = "SecureString"
  value = random_password.random_api_key.result
}
resource "aws_security_group" "rds" {
  description = "allows connections to RDS"
  name        = "mock-api-${var.environment_name}-rds-instance"
  vpc_id      = module.constants.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["${aws_security_group.allow-api-traffic.id}", "${aws_security_group.handle-csv.id}"]
  }
  egress {
    description      = "allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "mock_api_db" {
  identifier                      = "${var.environment_name}-wic-mt"
  allocated_storage               = 20
  engine                          = "postgres"
  engine_version                  = "13.7"
  instance_class                  = "db.t3.micro"
  db_name                         = "main"
  port                            = 5432
  enabled_cloudwatch_logs_exports = ["postgresql"]
  apply_immediately               = true
  deletion_protection             = true
  storage_encrypted               = true
  final_snapshot_identifier       = "${var.environment_name}-final"
  vpc_security_group_ids          = ["${aws_security_group.rds.id}"]
  username                        = data.aws_ssm_parameter.db_username.value
  password                        = aws_ssm_parameter.random_db_password.value
}