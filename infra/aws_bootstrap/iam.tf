# configurations for iam roles go here

# ----------------------------------------------------------
# 
# IAM Roles for Users
#
# ----------------------------------------------------------

# resource "aws_iam_role" "wic_mt_dev" {

# }

# ----------------------------------------------------------
# 
# data attributes for managed resources
#
# ----------------------------------------------------------
data "aws_ecr_repository" "eligibility-screener-repository" {
  name = "eligibility-screener-repo"
}

data "aws_ecr_repository" "mock-api-repository" {
  name = "mock-api-repo"
}

data "aws_ecs_service" "eligibility-screener-ecs-service" {
  service_name = "${var.environment_name}-ecs-service"
  cluster_arn = "arn:aws:ecs:us-east-1:546642427916:cluster/${var.environment_name}"
}

data "aws_ecs_service" "mock-api-ecs-service" {
  service_name = "${var.environment_name}-api-ecs-service"
  cluster_arn = "arn:aws:ecs:us-east-1:546642427916:cluster/${var.environment_name}"
}
data "aws_ecs_cluster" "application-cluster" {
  cluster_name = var.environment_name
}
# ----------------------------------------------------------
# 
# IAM Roles for FARGATE
#
# ----------------------------------------------------------

# Allows an IAM role to perform ECS tasks
data "aws_iam_policy_document" "ecs_assume_role_policy" {
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

data "aws_iam_policy_document" "access_ecr_policy" {
  statement {
    sid    = "AccessECR"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
    "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "access_ecr_policy" {
  name        = "wic-mt-access-ecr"
  policy      = data.aws_iam_policy_document.access_ecr_policy.json
  description = "Should allow access to the ECR repository."
}

resource "aws_iam_role_policy_attachment" "attach_ecs_to_ecr" {
  policy_arn = aws_iam_policy.access_ecr_policy.arn
  role       = aws_iam_role.ecs_executor.name
  depends_on = [
    aws_iam_role.ecs_executor
  ]
}
resource "aws_iam_role" "ecs_executor" {
  name               = "wic-mt-task-executor"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

# ----------------------------------------------------------
# 
# IAM Roles for Users
#
# ----------------------------------------------------------

resource "aws_iam_user" "github_actions" {
  name = "wic-mt-github-actions"
}
resource "aws_iam_role" "github_actions" {
  name               = "deployment-action"
  assume_role_policy = data.aws_iam_policy_document.github_actions.json
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    sid     = "WICDeploymentAssumeRole"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_user.github_actions.arn
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.deploy_action.arn
}

# add ecr perms (push)
data "aws_iam_policy_document" "deploy_action" {
  statement {
    sid     = "WICUpdateECR"
    actions = ["ecs:UpdateCluster", "ecs:UpdateService", "ecr:*"]
    resources = [
      data.aws_ecs_cluster.application-cluster.arn,
      data.aws_ecr_repository.eligibility-screener-repository.arn,
      data.aws_ecs_service.eligibility-screener-ecs-service.id,
      data.aws_ecs_service.mock-api-ecs-service.id,
      data.aws_ecr_repository.mock-api-repository.arn
    ]
  }
  statement {
    sid       = "WICLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy_action" {
  name   = "wic-mt-deploy"
  policy = data.aws_iam_policy_document.deploy_action.json
}

resource "aws_iam_user_policy_attachment" "deploy_action" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.deploy_action.arn
}

# ----------------------------------------------------------
# 
# Identity connector for AWS
#
# ----------------------------------------------------------

# I'm not entirely sure where to put this, but it releates to credentials and auth
# Github and AWS have a newer process for authenticating via scripts. Learn more here: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

# experiment with this later.
# resource "aws_iam_openid_connect_provider" "aws" {
#   url = "https://token.actions.githubusercontent.com"
#   client_id_list = ["sts.amazonaws.com"]
#   thumbprint_list = []
# }