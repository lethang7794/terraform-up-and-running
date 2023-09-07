# 05-cluster-web-server/main.tf

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDER
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "ap-southeast-1"
}

# ---------------------------------------------------------------------------------------------------------------------
# VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "server_port" {
  description = "the port the server will use for http requests"
  type        = number
  default     = 80
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "my_launch_config" {
  image_id        = "ami-0464f90f5928bccb8"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.ec2_instance.id]

  user_data = <<-EOF
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

  # Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.my_launch_config.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 5

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "random_uuid" "my_uuid" {
}

resource "aws_security_group" "ec2_instance" {
  name = "ec2-sg-${random_uuid.my_uuid.result}"

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

resource "aws_security_group" "alb" {
  name = "alb-sg-${random_uuid.my_uuid.result}"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------------------------------------------------
output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}
