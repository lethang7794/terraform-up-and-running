provider "aws" {
  region = "ap-southeast-1"
}

variable "project_name" {
  description = "Name of the Terraform Project"
  type        = string
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "tf-state-${var.project_name}"

  # Prevent accidental deletion of this S3 bucket 
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning so you can see the full revision history of your state files
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default 
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Explicitly block all public access to the S3 bucket 
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A DynamoDB table that has a primary key called LockID
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "tf-state-${var.project_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
