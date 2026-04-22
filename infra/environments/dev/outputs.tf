output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer — use as API base URL"
  value       = module.alb.alb_dns_name
}

output "rabbitmq_console_url" {
  description = "RabbitMQ management console URL"
  value       = module.ec2_rabbitmq.console_url
}

output "db_endpoint" {
  description = "PostgreSQL RDS endpoint hostname"
  value       = module.rds.db_endpoint
}

output "db_port" {
  description = "PostgreSQL port"
  value       = module.rds.db_port
}

output "ecr_api_rest" {
  description = "ECR URL for api-rest image"
  value       = module.ecr.api_rest_repo_url
}

output "ecr_consumer_pool" {
  description = "ECR URL for consumer-pool image"
  value       = module.ecr.consumer_pool_repo_url
}

output "ecr_consumer_delete" {
  description = "ECR URL for consumer-delete image"
  value       = module.ecr.consumer_delete_repo_url
}

output "ecr_update_task" {
  description = "ECR URL for update-task image"
  value       = module.ecr.update_task_repo_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}
