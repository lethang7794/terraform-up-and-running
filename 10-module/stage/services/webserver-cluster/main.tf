# 10-module/stage/services/web-server-cluster/main.tf
provider "aws" {
  region = "ap-southeast-1"
}

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"
}