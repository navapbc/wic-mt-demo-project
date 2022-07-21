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
  name            = "${var.environment_name}-ecs-service"
  cluster         = aws_ecs_cluster.mock-api-ecs-cluster.id
  task_definition = aws_ecs_task_definition.mock-api-ecs-task-definition.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = ["subnet-06b4ec8ff6311f69d"]
    assign_public_ip = true
  }
  desired_count = 1

  deployment_circuit_breaker {
    enable  = true
    rollback = true
  }
  force_new_deployment = true
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
