locals {
  automated_save_lambda_name = "${var.project_name}-auto-save"
}

data "archive_file" "automated_save" {
  type        = "zip"
  source_file = "${path.module}/auto-save/index.mjs"
  output_path = "${path.module}/auto-save/code.zip"
}

resource "aws_lambda_function" "automated_save" {
  filename         = "./auto-save/code.zip"
  function_name    = local.automated_save_lambda_name
  role             = aws_iam_role.automated_save.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.automated_save.output_base64sha256
  timeout          = 10
  runtime          = "nodejs22.x"
  environment {
    variables = {
      RCON_PORT                     = var.rcon_port,
      MC_SERVER_PRIVATE_DOMAIN_NAME = "${aws_service_discovery_service.minecraft.name}.${aws_service_discovery_private_dns_namespace.minecraft.name}",
    }
  }
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.automated_container_save.id]
  }
  layers = [aws_lambda_layer_version.rcon.arn]

  depends_on = [
    aws_cloudwatch_log_group.automated_save,
  ]
}

data "archive_file" "rcon_layer" {
  type        = "zip"
  source_dir  = "${path.module}/auto-save/layer"
  output_path = "${path.module}/auto-save/layer.zip"
}

resource "aws_lambda_layer_version" "rcon" {
  filename         = data.archive_file.rcon_layer.output_path
  layer_name       = "${var.project_name}-rcon-layer"
  source_code_hash = data.archive_file.rcon_layer.output_base64sha256

  compatible_runtimes = ["nodejs22.x"]
}

resource "aws_cloudwatch_log_group" "automated_save" {
  name              = "/aws/lambda/${local.automated_save_lambda_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_subscription_filter" "minecraft_server_players_online_filter" {
  name            = "${var.project_name}-players-online-filter"
  log_group_name  = aws_cloudwatch_log_group.automated_save.name
  filter_pattern  = "\"There are 0 of a max of\""
  destination_arn = aws_lambda_function.new_ecs_task.arn
}

resource "aws_lambda_permission" "minecraft_server_players_online_filter" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.new_ecs_task.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.automated_save.arn}:*"
}

resource "aws_security_group" "automated_container_save" {
  name        = "${var.project_name}-automated-container-save-lambda"
  description = "Allows connectivity to the ECS Minecraft server container."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = var.rcon_port
    to_port     = var.rcon_port
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

resource "aws_lambda_permission" "start_minecraft_server" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.new_ecs_task.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.aws_route53_minecraft_server_domain_dns_logs.arn}:*"
}

resource "aws_lambda_permission" "handle_automated_save" {
  statement_id  = "AllowExecutionFromEventBridgeAutomatedSave"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.automated_save.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.automated_save.arn
}

data "archive_file" "handle_launch" {
  type        = "zip"
  source_file = "${path.module}/launch/index.mjs"
  output_path = "${path.module}/launch/code.zip"
}

resource "aws_lambda_function" "new_ecs_task" {
  filename         = data.archive_file.handle_launch.output_path
  source_code_hash = data.archive_file.handle_launch.output_base64sha256
  function_name    = "${var.project_name}-handle-launch"
  role             = aws_iam_role.handle_launch_lambda.arn
  handler          = "index.handler"
  timeout          = 10
  runtime          = "nodejs22.x"
  environment {
    variables = {
      ECS_CLUSTER_NAME      = aws_ecs_cluster.minecraft.name
      MC_ECS_SERVICE_NAME   = "${aws_ecs_service.minecraft.name}",
      MC_SERVER_DOMAIN_NAME = "${var.minecraft_server_subdomain}.${data.aws_route53_zone.personal_domain.name}"
    }
  }
}

data "archive_file" "public_dns_config" {
  type        = "zip"
  source_file = "${path.module}/public-dns-config/index.mjs"
  output_path = "${path.module}/public-dns-config/code.zip"
}

resource "aws_lambda_function" "public_dns_config" {
  filename         = data.archive_file.public_dns_config.output_path
  source_code_hash = data.archive_file.public_dns_config.output_base64sha256
  function_name    = "${var.project_name}-public-dns-config"
  role             = aws_iam_role.public_dns_config_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"

  environment {
    variables = {
      ECS_CLUSTER_NAME      = aws_ecs_cluster.minecraft.name
      HOSTED_ZONE_ID        = data.aws_route53_zone.personal_domain.zone_id
      MC_SERVER_DOMAIN_NAME = "${var.minecraft_server_subdomain}.${data.aws_route53_zone.personal_domain.name}"
    }
  }
}

resource "aws_lambda_permission" "public_dns_config" {
  statement_id  = "AllowExecutionFromEventBridgePublicDNSConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.public_dns_config.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.public_dns_config.arn
}
