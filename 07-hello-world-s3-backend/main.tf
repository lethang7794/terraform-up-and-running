terraform {
  backend "s3" {
    bucket = "tf-state-07-hello-world-s3-backend"
    key    = "global/s3/terraform.tfstate"
    region = "ap-southeast-1"

    dynamodb_table = "tf-state-07-hello-world-s3-backend"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "random_uuid" "my_uuid" {}

resource "aws_s3_bucket" "main" {
  bucket = "s3-bucket-${random_uuid.my_uuid.result}"
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.main.bucket
}