# ---------------------------------------------------------------------------------------------------------------------
# VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "alb_name" {
  description = "Name of the ALB"
  type        = string
}

variable "subnet_ids" {
  description = "A set of subnet ids for the ALB"
  type        = set(string)
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}
