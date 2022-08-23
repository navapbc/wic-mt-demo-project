output "api_tags" {

  value = {
    project    = "mock-api"
    owner      = "wic-mt-demo"
    repository = "https://github.com/navapbc/wic-mt-demo-project-mock-api"
  }
}

output "vpc_id" {
  value       = "vpc-032e680f92b88bb68"
  description = "Default VPC provided by AWS"
}