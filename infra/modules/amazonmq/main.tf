resource "aws_mq_broker" "rabbitmq" {
  broker_name        = "${var.environment}-rabbitmq"
  engine_type        = "RABBITMQ"
  engine_version     = "3.11.20"
  deployment_mode    = "SINGLE_INSTANCE"
  host_instance_type = "mq.m5.large"

  subnet_ids         = [var.private_subnet_ids[0]]
  security_groups    = [var.sg_rabbitmq_id]
  publicly_accessible = false

  user {
    username = var.rabbitmq_username
    password = var.rabbitmq_password
  }

  logs {
    general = true
  }

  tags = {
    Name        = "${var.environment}-rabbitmq"
    Environment = var.environment
  }
}
