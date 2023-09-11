# 10-module/stage/services/web-server-cluster/outputs.tf

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------


output "alb_dns_name" {
  description = "The domain name of the load balancer"
  value       = module.webserver_cluster.alb_dns_name # Pass-through value from reusabled module outputs
}
