output "broker_id" {
  description = "ID of the Amazon MQ broker"
  value       = aws_mq_broker.rabbitmq.id
}

output "amqp_endpoint" {
  description = "AMQP endpoint for RabbitMQ connections"
  value       = tolist(aws_mq_broker.rabbitmq.instances)[0].endpoints[0]
}

output "console_url" {
  description = "URL of the RabbitMQ management console"
  value       = "https://${tolist(aws_mq_broker.rabbitmq.instances)[0].console_url}"
}
