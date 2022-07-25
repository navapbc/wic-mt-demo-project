# security group for screener
resource "aws_security_group" "allow-screener-traffic" {
  name = "allow_screener_traffic"
  description = "This rule blocks all traffic unless it is HTTPS for the eligibility screener"
  vpc_id = "vpc-032e680f92b88bb68" # don't like that this is hardcoded; default vpc
  # may need to update application to accept 80 then redirect.

  ingress {
    description = "TCP traffic from VPC"
    from_port = 80
    to_port   = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/8"]
  }

  egress {
    description = "allow all outbound traffic from screener"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecr_repository" "eligibility-screener-repository" {
  name                 = "eligibility-screener-repo"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "eligibility-screener-repo-policy" {
  repository = aws_ecr_repository.eligibility-screener-repository.name
  policy     = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1657823207798",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Effect": "Allow",
      "Principal": "*"
    }
  ]
  }
  EOF
}
# create a github and a user assume role for the principals ^

resource "aws_ecs_cluster" "eligibility-screener-ecs-cluster" {
  name = "${var.environment_name}"
}

resource "aws_ecs_service" "eligibility-screener-ecs-service" {
  name            = "${var.environment_name}-ecs-service"
  cluster         = aws_ecs_cluster.eligibility-screener-ecs-cluster.id
  task_definition = aws_ecs_task_definition.eligibility-screener-ecs-task-definition.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = ["subnet-06b4ec8ff6311f69d"]
    assign_public_ip = true
    security_groups = [aws_security_group.allow-screener-traffic.id]
  }
  desired_count = 1

  deployment_circuit_breaker {
    enable  = true
    rollback = true
  }
  force_new_deployment = true
}

resource "aws_ecs_task_definition" "eligibility-screener-ecs-task-definition" {
  family                   = "${var.environment_name}-ecs-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::546642427916:role/wic-mt-task-executor"
  container_definitions    = jsonencode([
    {
      name          = "${var.environment_name}-eligibility-screener-container"
      image         = "546642427916.dkr.ecr.us-east-1.amazonaws.com/eligibility-screener-repo:latest"
      memory        = 1024
      cpu           = 512
      essential     = true
      portMappings  = [
        {
          containerPort: 8080
        }
      ]
    }
  ])
}
