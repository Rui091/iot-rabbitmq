output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "api_rest_service_name" {
  description = "Name of the API REST ECS service"
  value       = aws_ecs_service.api_rest.name
}

output "consumer_pool_service_name" {
  description = "Name of the Consumer Pool ECS service"
  value       = aws_ecs_service.consumer_pool.name
}

output "consumer_delete_service_name" {
  description = "Name of the Consumer Delete ECS service"
  value       = aws_ecs_service.consumer_delete.name
}

output "update_task_service_name" {
  description = "Name of the Update Task ECS service"
  value       = aws_ecs_service.update_task.name
}
