variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS services"
  type        = list(string)
}

variable "sg_api_id" {
  description = "Security group ID for the API service"
  type        = string
}

variable "sg_consumers_id" {
  description = "Security group ID for consumer services"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group for the API service"
  type        = string
}

variable "db_endpoint" {
  description = "Hostname/IP of the PostgreSQL database"
  type        = string
}

variable "db_port" {
  description = "Port of the PostgreSQL database"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "tasksdb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "amqp_endpoint" {
  description = "AMQP endpoint URL for RabbitMQ"
  type        = string
}
