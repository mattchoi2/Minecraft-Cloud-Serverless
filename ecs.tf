resource "aws_ecr_repository" "minecraft" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_cloudwatch_log_group" "minecraft_logs" {
  name              = "${var.project_name}-fargate"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "minecraft" {
  family                   = "${var.project_name}-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  # See whole schema: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
  container_definitions = <<TASK_DEFINITION
[
  {
    "name": "${var.container_name}",
    "image": "${aws_ecr_repository.minecraft.repository_url}:latest",
    "cpu": 4096,
    "memory": ${var.memory},
    "essential": true,
    "stopTimeout": 120,
    "healthCheck": {
      "command": [
        "CMD-SHELL", 
        "mc-health || exit 1"
      ],
      "interval": 10,
      "timeout": 3,
      "retries": 3,
      "startPeriod": 180
    },
    "environment": [
      {
        "name": "EULA",
        "value": "TRUE"
      },
      {
        "name": "MEMORY",
        "value": "${var.memory}M"
      },
      {
        "name": "OPS",
        "value": "${var.op_admin_username}"
      },
      {
        "name": "DEBUG",
        "value": "true"
      },
      {
        "name": "LEVEL",
        "value": "worlds/${var.world_name}"
      },
      {
        "name": "RCON_PASSWORD",
        "value": "${var.rcon_password}"
      },
      {
        "name": "MOTD",
        "value": "Good morning gamers from a Fargate spot container!"
      },
      {
        "name": "WHITELIST",
        "value": "${var.whitelisted_minecraft_usernames}"
      }
    ],
    "portMappings": [
      {
        "name": "minecraft-port",
        "containerPort": 25565,
        "hostPort": 25565,
        "protocol": "tcp"
      },
      {
        "name": "rcon-port",
        "containerPort": ${var.rcon_port},
        "hostPort": ${var.rcon_port},
        "protocol": "tcp"
      }
    ],
    "mountPoints": [
      {
        "containerPath": "/data/worlds",
        "sourceVolume": "main-server-files"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-create-group": "true",
        "awslogs-group": "${aws_cloudwatch_log_group.minecraft_logs.name}",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "requiresCompatibilities": [
        "FARGATE"
    ]
  }
]
TASK_DEFINITION

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "main-server-files"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.minecraft.id
      root_directory = "/"
    }
  }
}

resource "aws_ecs_service" "minecraft" {
  name                   = "${var.project_name}-server"
  cluster                = aws_ecs_cluster.minecraft.id
  task_definition        = aws_ecs_task_definition.minecraft.family
  wait_for_steady_state  = true
  desired_count          = 1
  enable_execute_command = true
  network_configuration {
    subnets = aws_subnet.public[*].id
    security_groups = [
      aws_security_group.minecraft_server.id,
      aws_security_group.efs_endpoint.id
    ]
    assign_public_ip = true
  }

  capacity_provider_strategy {
    base              = 1
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.minecraft.arn
    container_name = var.container_name
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}

resource "aws_ecs_cluster" "minecraft" {
  name = "${var.project_name}-cluster"
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.minecraft_logs.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "minecraft" {
  cluster_name       = aws_ecs_cluster.minecraft.name
  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_service_discovery_private_dns_namespace" "minecraft" {
  name        = "minecraft.local"
  description = "This is a private domain name for secure private connections to the Minecraft server."
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "minecraft" {
  name = "${var.project_name}-server-discovery"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.minecraft.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
