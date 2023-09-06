# 02-single-server/main.tf
provider "aws" {            # Use AWS as our provider
  region = "ap-southeast-1" # Deploy into ap-southeast-1 region
}

resource "aws_instance" "my_ec2_instance" { # Deploy a AWS server (EC2 instance) named my_ec2_instance 
  ami           = "ami-0464f90f5928bccb8"
  instance_type = "t2.micro"

  tags = {
    "Name" = "my-awesome-ec2-instance-created-with-terraform"
  }
}
