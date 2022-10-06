# security group for screener
resource "aws_security_group" "allow-screener-traffic" {
  name        = "allow_screener_traffic"
  description = "This rule blocks all traffic unless it is HTTPS for the eligibility screener"
  vpc_id      = module.constants.vpc_id

  ingress {
    description = "HTTP traffic from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/8"]
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow traffic from internet"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
  }
  egress {
    description      = "allow all outbound traffic from screener"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_cluster" "eligibility-screener-ecs-cluster" {
  name = var.environment_name
}

resource "aws_ecs_service" "eligibility-screener-ecs-service" {
  name            = "${var.environment_name}-screener-ecs-service"
  cluster         = aws_ecs_cluster.eligibility-screener-ecs-cluster.id
  task_definition = aws_ecs_task_definition.eligibility-screener-ecs-task-definition.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = ["subnet-06b4ec8ff6311f69d"]
    assign_public_ip = true
    security_groups  = [aws_security_group.allow-screener-traffic.id]
  }
  desired_count = 1

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  force_new_deployment = true
}
data "aws_cloudwatch_log_group" "eligibility_screener" {
  name = "screener"
}
resource "aws_ecs_task_definition" "eligibility-screener-ecs-task-definition" {
  family                   = "${var.environment_name}-screener-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::546642427916:role/wic-mt-task-executor"
  container_definitions = jsonencode([
    {
      name      = "${var.environment_name}-eligibility-screener-container"
      image     = "546642427916.dkr.ecr.us-east-1.amazonaws.com/eligibility-screener-repo:latest-${var.environment_name}"
      memory    = 1024
      cpu       = 512
      essential = true
      portMappings = [
        {
          containerPort : 8080
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "${data.aws_cloudwatch_log_group.eligibility_screener.name}",
          "awslogs-region"        = "us-east-1",
          "awslogs-stream-prefix" = "screener"
        }
      }
    }
  ])
}
