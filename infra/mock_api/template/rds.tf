resource "aws_security_group" "rds" {
  description = "allows connections to RDS"
  name        = "rds-instance"
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
  vpc_security_group_ids          = ["${aws_security_group.rds.id}"]
  username                        = data.aws_ssm_parameter.db_username.value
  password                        = data.aws_ssm_parameter.db_pw.value
}