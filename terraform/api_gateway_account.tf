# ============================================================
# API Gateway Account Settings
# ============================================================
# API Gateway needs a single IAM role registered at the AWS
# account level before it can write logs to CloudWatch.
# This is a one-time account-wide setting — not per-API.
# Without this, any API Gateway stage with logging enabled
# will fail with: "CloudWatch Logs role ARN must be set"
# ============================================================

# IAM role that API Gateway will use to push logs to CloudWatch
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name        = "api-gateway-cloudwatch-logs-role"
  description = "Allows API Gateway to write logs to CloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach AWS managed policy — gives full CloudWatch Logs write access
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Register the role at the account level
# This tells AWS: "API Gateway in this account is allowed to use this role for logging"
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}
