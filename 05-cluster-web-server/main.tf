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
# AUTO SCALING GROUP (ACG)
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

  # Required when using a launch configuration with an ASG.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.my_launch_config.name

  vpc_zone_identifier = data.aws_subnets.default.ids # Use all the subnets in our Default VPC (by using the aws_subnets data source)
  # ⚠️ In production, the Auto Scaling Group should run in a private subnet

  target_group_arns = [aws_lb_target_group.asg.arn] # Attach our Auto Scaling Group with load balancer target group. AWS will automatically add and remove instances from the target group over its life cycle
  health_check_type = "ELB" # Use the target group’s health check 

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
  subnets            = data.aws_subnets.default.ids # Use all the subnets in our Default VPC (by using the aws_subnets data source). ⚠️ In production, we should create a new VPC 
  security_groups    = [aws_security_group.alb.id]  # Use the security group that allow HTTP rueqest on port 80
}

# A LB Listerer that listens on port 80 and protocol HTTP
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

# A LB Listerer Rule that sends requests that match any path to the target group that contains our Auto Scaling Group.
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

# A LB Target Group that performs health check our Instances by periodically sending an HTTP request to each Instance
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

# We don't need to create aws_lb_target_group_attachment to provide a static list of EC2 instance to Target Group
# With an Auto Scaling Group, Instances can launch or terminate at any time, so a static list won’t work
# The Auto Scaling Group has a first class integration with the Load Balancer, we just need to point the ASC to the Target Group

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "random_uuid" "my_uuid" {
}

# A Security Group that allows inbound request to EC2 instance port
resource "aws_security_group" "ec2_instance" {
  name = "ec2-sg-${random_uuid.my_uuid.result}"

 # Allow inbound HTTP requests on the server port
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests: so the EC2 instance can response to incoming request
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# By default, all AWS resources, including ALBs, don’t allow any incoming or outgoing traffic
# We need to create create a security group to allow incoming HTTP request on port 80
resource "aws_security_group" "alb" {
  name = "alb-sg-${random_uuid.my_uuid.result}"

  # Allow inbound HTTP requests on port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests: so load balancer can perform health checks
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
