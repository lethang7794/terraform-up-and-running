provider "aws" {
  region = "ap-southeast-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "secondary"
}

data "aws_region" "main" {
}

data "aws_region" "secondary" {
  provider = aws.secondary
}

output "region" {
  description = "The name of the region"
  value       = data.aws_region.main.name
}

output "region_secondary" {
  description = "The name of the secondary region"
  value       = data.aws_region.secondary.name
}
