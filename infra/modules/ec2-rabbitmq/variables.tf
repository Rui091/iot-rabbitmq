variable "environment" {
  type    = string
  default = "dev"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "sg_rabbitmq_id" {
  type = string
}

variable "rabbitmq_username" {
  type      = string
  sensitive = true
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}
