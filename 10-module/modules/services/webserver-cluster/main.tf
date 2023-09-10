# 10-module/modules/services/web-server-cluster/main.tf

terraform {
  backend "s3" {
    bucket = "tf-state-07-hello-world-s3-backend"
    key    = "stage/services/web-server-cluster/terraform.tfstate"
    region = "ap-southeast-1"

    dynamodb_table = "tf-state-07-hello-world-s3-backend"
    encrypt        = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTO SCALING GROUP (ACG)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_launch_configuration" "my_launch_config" {
  image_id        = "ami-0464f90f5928bccb8"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.ec2_instance.id]


  user_data = templatefile("user-data.sh", { # 🆕 templatefile function: reads the file at PATH, renders it as a template, and returns the result as a string.
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.db_address # 🆕 Read outputs them from the terraform_remote_state data source using an attribute reference
    db_port     = data.terraform_remote_state.db.outputs.db_port    # data.terraform_remote_state.<NAME>.outputs.<ATTRIBUTE>
  })

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
  health_check_type = "ELB"                         # Use the target group’s health check 

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

# 🆕 The terraform_remote_state data source 
# 🆕 uses the latest state snapshot from a specified state backend 
# 🆕 to retrieve the root module output values from some other Terraform configuration.
data "terraform_remote_state" "db" {
  backend = "s3" # The remote backend to use.

  #  The configuration of the remote backend
  config = {
    bucket = "tf-state-07-hello-world-s3-backend"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
