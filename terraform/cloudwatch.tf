# ============================================================
# CloudWatch Log Groups - explicit retention policy
# ============================================================
# Without this, logs are kept FOREVER and cost money.
# Industry standard: always define log groups explicitly.
# ============================================================

resource "aws_cloudwatch_log_group" "chat_lambda" {
  name              = "/aws/lambda/${local.name_prefix}-chat"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "history_lambda" {
  name              = "/aws/lambda/${local.name_prefix}-history"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}

# ============================================================
# CloudWatch Alarms - alert when things go wrong
# ============================================================

resource "aws_cloudwatch_metric_alarm" "chat_lambda_errors" {
  alarm_name          = "${local.name_prefix}-chat-errors"
  alarm_description   = "Chat Lambda is throwing errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.chat.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "chat_lambda_duration" {
  alarm_name          = "${local.name_prefix}-chat-duration"
  alarm_description   = "Chat Lambda approaching timeout"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.lambda_timeout * 1000 * 0.8
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.chat.function_name
  }
}
