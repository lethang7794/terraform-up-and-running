provider "aws" {
  region = "ap-southeast-1"
  alias  = "region_1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "region_2"
}

data "aws_region" "region_1" {
  provider = aws.region_1
}

data "aws_region" "region_2" {
  provider = aws.region_2
}


data "aws_ami" "ubuntu_region_1" {
  provider = aws.region_1

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

data "aws_ami" "ubuntu_region_2" {
  provider = aws.region_2

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

output "region_1" {
  value = data.aws_region.region_1.id
}

output "region_2" {
  value = data.aws_region.region_2.id
}

output "ubuntu_region_1_id" {
  value = data.aws_ami.ubuntu_region_1.id
}

output "ubuntu_region_2_id" {
  value = data.aws_ami.ubuntu_region_2.id
}

output "ubuntu_region_1_name" {
  value = data.aws_ami.ubuntu_region_1.name
}

output "ubuntu_region_2_name" {
  value = data.aws_ami.ubuntu_region_2.name
}
