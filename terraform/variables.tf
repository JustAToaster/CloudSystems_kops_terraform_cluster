variable "db_username" {
  description = "RDS username"
}

variable "db_password" {
  description = "RDS root user password"
  sensitive   = true
}