
provider "aws" {
  region = "ap-southeast-1"
}

resource "random_uuid" "my_uuid" {}

resource "aws_s3_bucket" "main" {
  bucket = "s3-bucket-${random_uuid.my_uuid.result}"

  provisioner "local-exec" {
    command = "echo \"Hello, World from $(uname -a)\""
  }
}

# resource "aws_s3_bucket_versioning" "main" {
#   bucket = aws_s3_bucket.main.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }


output "s3_bucket_name" {
  value = aws_s3_bucket.main.bucket
}
