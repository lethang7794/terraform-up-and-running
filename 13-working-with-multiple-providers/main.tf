provider "aws" {            # aws is the preferred local name for AWS Provider
  region = "ap-southeast-1" #
  alias  = "main"           # A custom local name for AWS Provider
}

provider "aws" {
  region = "us-east-1"
  alias  = "secondary"
}

data "aws_region" "main" {
  provider = aws.main
}

data "aws_region" "secondary" {
  provider = aws.secondary
}

output "region_main" {
  description = "The name of the main region"
  value       = data.aws_region.main.name
}

output "region_secondary" {
  description = "The name of the secondary region"
  value       = data.aws_region.secondary.name
}
