
resource "aws_cloudwatch_event_rule" "automated_save" {
  name        = "${var.project_name}-minecraft-server-save"
  description = "Save all Minecraft server instances automatically on a regular schedule."
  # Hourly at minute 0
  schedule_expression = "cron(/15 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "automated_save_container" {
  rule = aws_cloudwatch_event_rule.automated_save.id
  arn  = aws_lambda_function.automated_save.arn
}

resource "aws_cloudwatch_event_rule" "public_dns_config" {
  name        = "${var.project_name}-new-ecs-container-configure-public-dns"
  description = "Capture a fargate container launch to configure the EIP."

  event_pattern = <<EOF
{
  "source": ["aws.ecs"],
  "detail-type": ["ECS Task State Change"],
  "detail": {
    "lastStatus": ["RUNNING"],
    "desiredStatus": ["RUNNING"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "public_dns_config" {
  arn  = aws_lambda_function.public_dns_config.arn
  rule = aws_cloudwatch_event_rule.public_dns_config.id
}
