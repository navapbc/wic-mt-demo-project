resource "aws_ecr_repository" "eligibility-screener-repository" {
  name                 = "eligibility-screener-repo"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "mock-api-repository" {
  name                 = "mock-api-repo"
  image_tag_mutability = "MUTABLE"
}