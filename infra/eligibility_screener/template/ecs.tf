# ---------------------------------------
#
# Security Groups
#
# ---------------------------------------
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
    description      = "VPC CIDR; allows healthchecks"
    from_port        = 8080
    protocol         = "tcp"
    to_port          = 8080
    cidr_blocks      = ["0.0.0.0/0"]
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

resource "aws_security_group" "allow-lb-traffic" {
  name        = "screener_load_balancer_sg"
  description = "Allows load balancers to communicate with tasks"
  vpc_id      = module.constants.vpc_id

  ingress {
    description = "HTTP traffic from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "allow lb traffic"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    security_groups  = [
        "sg-0c50cf775611d9db2",
      ]
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

# ---------------------------------------
#
# Load Balancing
#
# ---------------------------------------

resource "aws_lb" "eligibility-screener" {
  name = "${var.environment_name}-screener-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.allow-lb-traffic.id]
  subnets = [
    "subnet-05b0618f4ef1a808c",
    "subnet-06067596a1f981034",
    "subnet-06b4ec8ff6311f69d",
    "subnet-08d7f1f9802fd20c4",
    "subnet-09c317466f27bb9bb",
    "subnet-0ccc97c07aa49a0ae"
  ] # find a way to map all the default ones here; hardcoding for now
  ip_address_type = "ipv4"
  desync_mitigation_mode = "defensive"
}

# must be ip!!
resource "aws_lb_target_group" "eligibility-screener" {
  name = "${var.environment_name}-screener-lb"
  port = 3000
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = module.constants.vpc_id
  health_check {
    enabled = true
    port = 3000
  }
}

resource "aws_lb_listener" "screener" {
  load_balancer_arn = aws_lb.eligibility-screener.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.eligibility-screener.arn
  }
}
# ---------------------------------------
#
# ECS
#
# ---------------------------------------
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

  load_balancer {
    target_group_arn = aws_lb_target_group.eligibility-screener.arn
    # target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:546642427916:targetgroup/screener-lb-3000/72e92f65fe721cd1" # hardcoded for test purposes; wic-mt-screener target group
    container_name = "${var.environment_name}-eligibility-screener-container" # from the task definition 
    container_port = 3000 # from the exposed docker container on the screener
  }
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
          containerPort : 3000
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
