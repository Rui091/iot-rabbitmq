data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  ecr_base   = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"
}

# ─── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "tasks-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "tasks-cluster"
    Environment = var.environment
  }
}

# ─── IAM: Task Execution Role (Learner Lab Workaround) ───────────────────────────
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ─── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api_rest" {
  name              = "/ecs/api-rest"
  retention_in_days = 7

  tags = {
    Name        = "/ecs/api-rest"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "consumers" {
  name              = "/ecs/consumers"
  retention_in_days = 7

  tags = {
    Name        = "/ecs/consumers"
    Environment = var.environment
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE: API REST
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_ecs_task_definition" "api_rest" {
  family                   = "${var.environment}-api-rest"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-rest"
      image     = "${local.ecr_base}/api-rest:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_HOST",      value = var.db_endpoint },
        { name = "DB_PORT",      value = tostring(var.db_port) },
        { name = "DB_NAME",      value = var.db_name },
        { name = "DB_USER",      value = var.db_username },
        { name = "DB_PASSWORD",  value = var.db_password },
        { name = "RABBITMQ_URL", value = var.amqp_endpoint },
        { name = "PORT",         value = "8080" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api_rest.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "api-rest"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.environment}-api-rest"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "api_rest" {
  name            = "${var.environment}-api-rest"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_rest.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_api_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api-rest"
    container_port   = 8080
  }



  tags = {
    Name        = "${var.environment}-api-rest"
    Environment = var.environment
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE: CONSUMER POOL
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_ecs_task_definition" "consumer_pool" {
  family                   = "${var.environment}-consumer-pool"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "consumer-pool"
      image     = "${local.ecr_base}/consumer-pool:latest"
      essential = true
      environment = [
        { name = "DB_HOST",      value = var.db_endpoint },
        { name = "DB_PORT",      value = tostring(var.db_port) },
        { name = "DB_NAME",      value = var.db_name },
        { name = "DB_USER",      value = var.db_username },
        { name = "DB_PASSWORD",  value = var.db_password },
        { name = "RABBITMQ_URL", value = var.amqp_endpoint },
        { name = "QUEUE_NAME",   value = "tasks_queue" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.consumers.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "consumer-pool"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.environment}-consumer-pool"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "consumer_pool" {
  name            = "${var.environment}-consumer-pool"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.consumer_pool.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_consumers_id]
    assign_public_ip = false
  }



  tags = {
    Name        = "${var.environment}-consumer-pool"
    Environment = var.environment
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE: CONSUMER DELETE
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_ecs_task_definition" "consumer_delete" {
  family                   = "${var.environment}-consumer-delete"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "consumer-delete"
      image     = "${local.ecr_base}/consumer-delete:latest"
      essential = true
      environment = [
        { name = "DB_HOST",      value = var.db_endpoint },
        { name = "DB_PORT",      value = tostring(var.db_port) },
        { name = "DB_NAME",      value = var.db_name },
        { name = "DB_USER",      value = var.db_username },
        { name = "DB_PASSWORD",  value = var.db_password },
        { name = "RABBITMQ_URL", value = var.amqp_endpoint },
        { name = "QUEUE_NAME",   value = "delete_queue" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.consumers.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "consumer-delete"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.environment}-consumer-delete"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "consumer_delete" {
  name            = "${var.environment}-consumer-delete"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.consumer_delete.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_consumers_id]
    assign_public_ip = false
  }



  tags = {
    Name        = "${var.environment}-consumer-delete"
    Environment = var.environment
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SERVICE: UPDATE TASK
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_ecs_task_definition" "update_task" {
  family                   = "${var.environment}-update-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "update-task"
      image     = "${local.ecr_base}/update-task:latest"
      essential = true
      environment = [
        { name = "DB_HOST",      value = var.db_endpoint },
        { name = "DB_PORT",      value = tostring(var.db_port) },
        { name = "DB_NAME",      value = var.db_name },
        { name = "DB_USER",      value = var.db_username },
        { name = "DB_PASSWORD",  value = var.db_password },
        { name = "RABBITMQ_URL", value = var.amqp_endpoint },
        { name = "QUEUE_NAME",   value = "update_queue" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.consumers.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "update-task"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.environment}-update-task"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "update_task" {
  name            = "${var.environment}-update-task"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.update_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_consumers_id]
    assign_public_ip = false
  }



  tags = {
    Name        = "${var.environment}-update-task"
    Environment = var.environment
  }
}
