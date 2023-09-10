# 10-module/modules/data-stores/mysql/main.tf
terraform {
  backend "s3" {
    bucket = "tf-state-07-hello-world-s3-backend"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "ap-southeast-1"

    dynamodb_table = "tf-state-07-hello-world-s3-backend"
    encrypt        = true
  }
}

resource "random_pet" "address" {
  prefix = "my-db"
}

resource "random_integer" "port" {
  max = 9999
  min = 1000
}