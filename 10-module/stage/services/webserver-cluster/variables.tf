# 10-module/stage/services/web-server-cluster/variables.tf

# ---------------------------------------------------------------------------------------------------------------------
# VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "server_port" {
  description = "the port the server will use for http requests"
  type        = number
  default     = 80
}