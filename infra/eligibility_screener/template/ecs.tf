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
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow traffic from internet"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
  }
  ingress {
    cidr_blocks      = ["172.31.0.0/16"]
    description      = "HTTPS traffic from VPC"
    from_port        = 443
    protocol         = "tcp"
    to_port          = 443
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

resource "aws_ecr_repository" "eligibility-screener-repository" {
  name                 = "eligibility-screener-repo"
  image_tag_mutability = "MUTABLE"
}
data "aws_iam_policy_document" "ecr-perms" {
  statement {
    sid = "ECRPerms"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetLifecyclePolicy",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_ecr_repository_policy" "eligibility-screener-repo-policy" {
  repository = aws_ecr_repository.eligibility-screener-repository.name
  policy     = data.aws_iam_policy_document.ecr-perms.json
}
# create a github and a user assume role for the principals ^

resource "aws_ecs_cluster" "eligibility-screener-ecs-cluster" {
  name = var.environment_name
}

resource "aws_ecs_service" "eligibility-screener-ecs-service" {
  name            = "${var.environment_name}-ecs-service"
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

resource "aws_ecs_task_definition" "eligibility-screener-ecs-task-definition" {
  family                   = "${var.environment_name}-ecs-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::546642427916:role/wic-mt-task-executor"
  container_definitions = jsonencode([
    {
      name      = "${var.environment_name}-eligibility-screener-container"
      image     = "546642427916.dkr.ecr.us-east-1.amazonaws.com/eligibility-screener-repo:latest"
      memory    = 1024
      cpu       = 512
      essential = true
      portMappings = [
        {
          containerPort : 8080
        }
      ]
    }
  ])
}
