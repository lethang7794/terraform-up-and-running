provider "aws" {
  region = "us-east-2"
  alias  = "region_1"
}

provider "aws" {
  region = "us-west-1"
  alias  = "region_2"
}

resource "aws_instance" "region_1" {
  provider = aws.region_1

  ami           = "ami-0fb653ca2d3203ac1" # Note different AMI IDs!!
  instance_type = "t2.micro"
}

resource "aws_instance" "region_2" {
  provider = aws.region_2

  ami           = "ami-01f87c43e618bf8f0" # Note different AMI IDs!!
  instance_type = "t2.micro"
}
