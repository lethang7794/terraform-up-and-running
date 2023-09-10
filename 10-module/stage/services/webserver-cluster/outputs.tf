# 10-module/stage/services/web-server-cluster/outputs.tf

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "alb_dns_name" {
  description = "The domain name of the load balancer"
  value       = aws_lb.example.dns_name
}
