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
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access_ecr_policy"{
  statement {
    sid = "AccessECR"
    effect = "Allow"
    actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"]
    resources = [ "*" ]
  }
}

resource "aws_iam_policy" "access_ecr_policy" {
  name = "wic-mt-access-ecr"
  policy = data.aws_iam_policy_document.access_ecr_policy.json
  description = "Should allow access to the ECR repository."
}

resource "aws_iam_role_policy_attachment" "attach_ecs_to_ecr" {
  policy_arn = aws_iam_policy.access_ecr_policy.arn
  role = aws_iam_role.ecs_executor.name
  depends_on = [
    aws_iam_role.ecs_executor
  ]
}
resource "aws_iam_role" "ecs_executor" {
  name = "wic-mt-task-executor"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}


# For a later ticket: This policy allows access to parameter store secrets. Uncomment and add "resources" field
# data "aws_iam_policy_document" "ecs_access_policy" {
#   statement {
#     sid = "LogToCloudwatch"
#     actions = [
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogStreams"
#     ]
#   }

#   statement {
#     sid = "AccessSecrets"
#     actions = [
#       "ssm:GetParameter",
#       "ssm:GetParameters",
#     ]
#   }
  
# }

# resource "aws_iam_role_policy" "task_access_policy" {
#   name = "wic-mt-task-access"
#   role = aws_iam_role.ecs_executor.id
#   policy = data.aws_iam_policy_document.ecs_access_policy.json
  
# }
