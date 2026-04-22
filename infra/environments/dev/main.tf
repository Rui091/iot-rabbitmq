terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Networking ────────────────────────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  aws_region  = var.aws_region
  environment = var.environment
}

# ─── Security Groups ───────────────────────────────────────────────────────────
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.networking.vpc_id
  environment = var.environment
}

# ─── ALB ───────────────────────────────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  sg_alb_id         = module.security_groups.sg_alb_id
}

# ─── EC2 RabbitMQ (Learner Lab Workaround) ───────────────────────────────────
module "ec2_rabbitmq" {
  source = "../../modules/ec2-rabbitmq"

  environment        = var.environment
  private_subnet_ids = module.networking.private_subnet_ids
  sg_rabbitmq_id     = module.security_groups.sg_rabbitmq_id
  rabbitmq_username  = var.rabbitmq_username
  rabbitmq_password  = var.rabbitmq_password
}

# ─── RDS PostgreSQL (Option A — Recommended) ───────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  environment        = var.environment
  private_subnet_ids = module.networking.private_subnet_ids
  sg_rds_id          = module.security_groups.sg_rds_id
  db_username        = var.db_username
  db_password        = var.db_password
}

# ─── ECR Repositories ──────────────────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment
}

# ─── ECS Cluster + Services ────────────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs"

  environment        = var.environment
  private_subnet_ids = module.networking.private_subnet_ids
  sg_api_id          = module.security_groups.sg_api_id
  sg_consumers_id    = module.security_groups.sg_consumers_id
  target_group_arn   = module.alb.target_group_arn
  db_endpoint        = module.rds.db_endpoint
  db_port            = module.rds.db_port
  db_name            = module.rds.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  amqp_endpoint      = module.ec2_rabbitmq.amqp_endpoint
}
