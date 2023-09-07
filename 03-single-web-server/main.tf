# 03-single-web-server/main.tf
provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_instance" "my_ec2_instance" {
  ami                    = "ami-0464f90f5928bccb8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_securiy_group.id]

  user_data                   = <<-EOF
                                #!/bin/bash
                                sudo dnf update -y
                                sudo dnf install -y httpd
                                sudo systemctl start httpd
                                
                                TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
                                PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4`
                                
                                sudo chmod 777 /var/www/html -R
                                sudo echo "Hello, World from $PUBLIC_IP" > /var/www/html/index.html
                                EOF
  user_data_replace_on_change = true

  tags = {
    "Name" = "my_web_server"
  }
}


resource "aws_security_group" "my_securiy_group" {
  name = "my_web_server_sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
