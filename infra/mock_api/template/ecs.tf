data "aws_ecr_repository" "mock-api-repository" {
  name = "mock-api-repo"
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

resource "aws_ecr_repository_policy" "mock-api-repo-policy" {
  repository = data.aws_ecr_repository.mock-api-repository.name
  policy     = data.aws_iam_policy_document.ecr-perms.json
}


resource "aws_ecs_cluster" "mock-api-ecs-cluster" {
  name = var.environment_name
}

resource "aws_ecs_service" "mock-api-ecs-service" {
  name            = "${var.environment_name}-api-ecs-service"
  cluster         = aws_ecs_cluster.mock-api-ecs-cluster.id
  task_definition = aws_ecs_task_definition.mock-api-ecs-task-definition.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = ["subnet-06b4ec8ff6311f69d"]
    assign_public_ip = true
    security_groups  = [aws_security_group.allow-api-traffic.id]
  }
  desired_count = 1

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  force_new_deployment = true
}

resource "aws_security_group" "allow-api-traffic" {
  name        = "allow_api_traffic"
  description = "This rule blocks all traffic unless it is HTTPS for the eligibility screener"
  vpc_id      = module.constants.vpc_id

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # use security group as the source
    cidr_blocks = ["172.31.0.0/16"] # ip range of the VPC
  }

  # This is for testing purposes ONLY
  ingress {
    description = "Allow all traffic for testing"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

data "aws_cloudwatch_log_group" "mock_api" {
  name = "mock-api"
}
resource "aws_ecs_task_definition" "mock-api-ecs-task-definition" {
  family                   = "${var.environment_name}-api-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::546642427916:role/wic-mt-task-executor"
  container_definitions = jsonencode([
    {
      name      = "${var.environment_name}-mock-api-container"
      image     = "546642427916.dkr.ecr.us-east-1.amazonaws.com/mock-api-repo:latest"
      memory    = 1024
      cpu       = 512
      essential = true
      portMappings = [
        {
          containerPort : 8080
        }
      ]
      readonlyRootFilesystem = true
      linuxParameters = {
        capabilities = {
          drop = ["ALL"]
        },
        initProcessEnabled = true
      }
      environment : [
        {
          "name" : "ENVIRONMENT"
          "value" : "${var.environment_name}"
        },
        {
          "name" : "POSTGRES_USER"
          "value" : "${data.aws_ssm_parameter.db_username.value}"
        },
        {
          "name" : "POSTGRES_PASSWORD"
          "value" : "${data.aws_ssm_parameter.db_pw.value}"
        },
        {
          "name" : "POSTGRES_DB"
          "value" : "${aws_db_instance.mock_api_db.name}"
        },
        {
          "name" : "DB_HOST"
          "value" : "${aws_db_instance.mock_api_db.address}"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "mock-api",
          "awslogs-region"        = "us-east-1",
          "awslogs-stream-prefix" = "mock-api"
        }
      }
    }
  ])
}
# ------------------------------------------------------------------------------
#    ECS task to Handle CSVs
#
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "task_assume_role_policy" {
  statement {
    sid = "ECSTaskExecution"
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "handle-csv" {
  name               = "handle-csv-role"
  description        = "allows an ECS task to generate CSVs and manage their storage"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy.json
}
resource "aws_iam_role_policy_attachment" "handle-csv" {
  policy_arn = aws_iam_policy.handle-csv.arn
  role       = aws_iam_role.handle-csv.name
}
resource "aws_iam_policy" "handle-csv" {
  name   = "handle-csv"
  policy = data.aws_iam_policy_document.handle-csv.json
}
data "aws_iam_policy_document" "handle-csv" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.wic-mt-csv-files.arn}", "${aws_s3_bucket.wic-mt-csv-files.arn}/*"]
  }
}

resource "aws_security_group" "handle-csv" {
  description = "allows connections for the csv generation ecs task"
  name        = "ecs-task-security-group"
  vpc_id      = module.constants.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["${aws_security_group.allow-api-traffic.id}"]
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
resource "aws_ecs_task_definition" "handle-csv" {
  family                   = "${var.environment_name}-csv-handler-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "1024"
  cpu                      = "512"
  task_role_arn            = aws_iam_role.handle-csv.arn
  execution_role_arn       = "arn:aws:iam::546642427916:role/wic-mt-task-executor"
  container_definitions = jsonencode([
    {
      name      = "${var.environment_name}-mock-api-container"
      image     = "546642427916.dkr.ecr.us-east-1.amazonaws.com/mock-api-repo:latest"
      memory    = 1024
      cpu       = 512
      essential = true
      command   = ["poetry", "run", "create-eligibility-screener-csv"]
      portMappings = [
        {
          containerPort : 8080
        }
      ]
      linuxParameters = {
        capabilities = {
          drop = ["ALL"]
        },
        initProcessEnabled = true
      }
      environment : [
        {
          "name" : "ENVIRONMENT"
          "value" : "${var.environment_name}"
        },
        {
          "name" : "POSTGRES_USER"
          "value" : "${data.aws_ssm_parameter.db_username.value}"
        },
        {
          "name" : "POSTGRES_PASSWORD"
          "value" : "${data.aws_ssm_parameter.db_pw.value}"
        },
        {
          "name" : "POSTGRES_DB"
          "value" : "${aws_db_instance.mock_api_db.name}"
        },
        {
          "name" : "DB_HOST"
          "value" : "${aws_db_instance.mock_api_db.address}"
        },
        {
          "name" : "ELIGIBILITY_SCREENER_CSV_OUTPUT_PATH"
          "value" : "s3://${aws_s3_bucket.wic-mt-csv-files.id}"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "mock-api",
          "awslogs-region"        = "us-east-1",
          "awslogs-stream-prefix" = "csv-handler"
        }
      }
    }
  ])
}
