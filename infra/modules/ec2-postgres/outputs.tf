output "db_endpoint" {
  description = "Private IP of the EC2 PostgreSQL instance"
  value       = aws_instance.postgres.private_ip
}

output "db_port" {
  description = "Port of the PostgreSQL service"
  value       = 5432
}

output "db_name" {
  description = "Name of the database"
  value       = "tasksdb"
}
