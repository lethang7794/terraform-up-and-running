# 04-configuration-web-server/main.tf

provider "aws" {
  region = "ap-southeast-1"
}

variable "server_port" {
  description = "the port the server will use for http requests"
  type        = number
  default     = 80
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

                                # Check if the Apache configuration file exists
                                if [ -f /etc/httpd/conf/httpd.conf ]; then
                                    # Backup the original configuration file
                                    sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
                                    
                                    # Use sed to replace the default port 80 with ${var.server_port}
                                    sudo sed -i 's/Listen 80/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
                                    
                                    # Restart Apache to apply the changes
                                    sudo systemctl restart httpd
                                    echo "Apache HTTP port changed to ${var.server_port}. Make sure to update your firewall rules if necessary."
                                else
                                    echo "Apache configuration file not found. Please update the script with the correct path."
                                fi
                                EOF
  user_data_replace_on_change = true

  tags = {
    "Name" = "my_web_server"
  }
}

resource "random_uuid" "my_uuid" {
}

resource "aws_security_group" "my_securiy_group" {
  name = "tf-sg-${random_uuid.my_uuid.result}"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ DO NOT DO THIS IN PRODUCTION
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_ip" {
  value       = aws_instance.my_ec2_instance.public_ip
  description = "The public IP address of the web server"
}

output "public_dns" {
  value       = aws_instance.my_ec2_instance.public_dns
  description = "The public domain of the web server"
}

output "public_url" {
  value       = "http://${aws_instance.my_ec2_instance.public_dns}:${var.server_port}"
  description = "The public url of the web server"
}
