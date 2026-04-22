output "sg_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "sg_api_id" {
  description = "ID of the API security group"
  value       = aws_security_group.api.id
}

output "sg_rabbitmq_id" {
  description = "ID of the RabbitMQ security group"
  value       = aws_security_group.rabbitmq.id
}

output "sg_consumers_id" {
  description = "ID of the consumers security group"
  value       = aws_security_group.consumers.id
}

output "sg_rds_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}
