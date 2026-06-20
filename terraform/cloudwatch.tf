# ============================================================
# CloudWatch Log Groups — explicit retention policy
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
# CloudWatch Alarms — alert when things go wrong
# ============================================================

# Alarm when chat Lambda errors spike
resource "aws_cloudwatch_metric_alarm" "chat_lambda_errors" {
  alarm_name          = "${local.name_prefix}-chat-errors"
  alarm_description   = "Chat Lambda is throwing errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60       # Check every 60 seconds
  evaluation_periods  = 2        # Trigger after 2 consecutive periods
  threshold           = 5        # Alert if more than 5 errors in a minute
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.chat.function_name
  }
}

# Alarm when Lambda is near timeout (p99 duration > 80% of timeout)
resource "aws_cloudwatch_metric_alarm" "chat_lambda_duration" {
  alarm_name          = "${local.name_prefix}-chat-duration"
  alarm_description   = "Chat Lambda approaching timeout"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.lambda_timeout * 1000 * 0.8   # 80% of timeout in ms
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.chat.function_name
  }
}
