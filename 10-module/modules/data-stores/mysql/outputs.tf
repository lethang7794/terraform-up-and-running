# 10-module/modules/data-stores/mysql/outputs.tf

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "db_address" {
  description = "Connect to the database at this endpoint"
  value       = "${random_pet.address.id}.ap-southeast-1.rds.amazonaws.com"
}

output "db_port" {
  description = "The port the database is listening on"
  value       = random_integer.port.id
}

output "db_address" {
  value       = aws_db_instance.example.address
  description = "Connect to the database at this endpoint"
}

output "db_port" {
  value       = aws_db_instance.example.port
  description = "The port the database is listening on"
}