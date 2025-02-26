data "aws_route53_zone" "personal_domain" {
  name = var.minecraft_server_domain
}

resource "aws_cloudwatch_log_group" "aws_route53_minecraft_server_domain_dns_logs" {
  name              = "/aws/route53/${data.aws_route53_zone.personal_domain.name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_subscription_filter" "aws_route53_minecraft_server_domain_dns_logs" {
  name            = "${var.project_name}-dns-queries-filter"
  log_group_name  = aws_cloudwatch_log_group.aws_route53_minecraft_server_domain_dns_logs.name
  filter_pattern  = "${data.aws_route53_zone.personal_domain.zone_id} ${data.aws_route53_zone.personal_domain.name}"
  destination_arn = aws_lambda_function.new_ecs_task.arn
}

resource "aws_route53_query_log" "example_com" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_logging]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.aws_route53_minecraft_server_domain_dns_logs.arn
  zone_id                  = data.aws_route53_zone.personal_domain.zone_id
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_logging" {
  policy_name     = "${var.project_name}-route53-query-logging-policy"
  policy_document = data.aws_iam_policy_document.route53_query_logging.json
}

data "aws_iam_policy_document" "route53_query_logging" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:log-group:/aws/route53/*"]

    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}
