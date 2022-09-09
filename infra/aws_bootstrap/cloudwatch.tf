# cloudwatch configs go here
# we need insight into the ecs tasks

# ----------------------------------------------
# Mock API
# ----------------------------------------------
resource "aws_cloudwatch_log_group" "mock_api" {
  name              = "mock-api"
  retention_in_days = 90
}

# ----------------------------------------------
# Eligibility Screener
# ----------------------------------------------
resource "aws_cloudwatch_log_group" "eligibility_screener" {
  name              = "screener"
  retention_in_days = 90
}
