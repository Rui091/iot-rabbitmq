output "amqp_endpoint" {
  description = "AMQP endpoint for RabbitMQ connections"
  value       = "amqp://${aws_instance.rabbitmq.private_ip}:5672"
}

output "console_url" {
  description = "URL of the RabbitMQ management console"
  value       = "http://${aws_instance.rabbitmq.private_ip}:15672"
}
