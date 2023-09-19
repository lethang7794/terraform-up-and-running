# 13-6/modules/data-stores/mysql/outputs.tf


# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "address" {
  description = "Connect to the database at this endpoint"
  value       = aws_db_instance.example.address
}

output "port" {
  description = "The port the database is listening on"
  value       = aws_db_instance.example.port
}

output "arn" {
  value       = aws_db_instance.example.arn
  description = "The ARN of the database"
}


