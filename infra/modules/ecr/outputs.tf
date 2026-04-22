output "api_rest_repo_url" {
  description = "ECR URL for the api-rest image"
  value       = aws_ecr_repository.repos["api_rest"].repository_url
}

output "consumer_pool_repo_url" {
  description = "ECR URL for the consumer-pool image"
  value       = aws_ecr_repository.repos["consumer_pool"].repository_url
}

output "consumer_delete_repo_url" {
  description = "ECR URL for the consumer-delete image"
  value       = aws_ecr_repository.repos["consumer_delete"].repository_url
}

output "update_task_repo_url" {
  description = "ECR URL for the update-task image"
  value       = aws_ecr_repository.repos["update_task"].repository_url
}
