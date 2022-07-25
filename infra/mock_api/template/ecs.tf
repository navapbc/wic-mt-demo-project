# fargate config goes in this file
# create task def
# may need script to trigger task aftwerwards
# create service and schedule (optional)
# networking??
  # security groups, etc

# may need to set security group perms
resource "aws_ecr_repository" "mock-api-repository" {
  name                 = "mock-api-repo"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "mock-api-repo-policy" {
  repository = aws_ecr_repository.mock-api-repository.name
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

resource "aws_ecs_cluster" "mock-api-ecs-cluster" {
  name = "${var.environment_name}"
}

resource "aws_ecs_service" "mock-api-ecs-service" {
  name            = "${var.environment_name}-api-ecs-service"
  cluster         = aws_ecs_cluster.mock-api-ecs-cluster.id
  task_definition = aws_ecs_task_definition.mock-api-ecs-task-definition.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = ["subnet-06b4ec8ff6311f69d"]
    assign_public_ip = true
    security_groups = [aws_security_group.allow-api-traffic.id]
  }
  desired_count = 1

  deployment_circuit_breaker {
    enable  = true
    rollback = true
  }
  force_new_deployment = true
}

resource "aws_security_group" "allow-api-traffic" {
  name = "allow_api_traffic"
  description = "This rule blocks all traffic unless it is HTTPS for the eligibility screener"
  vpc_id = "vpc-032e680f92b88bb68" # don't like that this is hardcoded; default vpc

  ingress {
    description = "Allow traffic from screener"
    from_port = 443
    to_port   = 443
    protocol = "tcp"
    # use security group as the source
    cidr_blocks = ["10.0.0.0/8"]
  }

  # This is for testing purposes ONLY
  ingress {
    description = "Allow all traffic for testing"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
# add public ip to security group

# todo: change container def to data block
# todo: specify security group
  # use ur own ip for testing
  # resource aws_security_group
# todo: specify resources for access under networking
# todo: create ALB and autoscaling
# todo: limit principals and resources to grant least privelege
# todo: create plan to migrate all of this + infra in eligibility screener to one repo
# todo: make decision on initial deploy. should users let it fail and then deploy again?
resource "aws_ecs_task_definition" "mock-api-ecs-task-definition" {
  family                   = "${var.environment_name}-ecs-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::546642427916:role/wic-mt-task-executor"
  container_definitions    = jsonencode([
    {
      name          = "${var.environment_name}-mock-api-container"
      image         = "546642427916.dkr.ecr.us-east-1.amazonaws.com/mock-api-repo:latest"
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
