# ============================================================
# API Gateway REST API
# ============================================================
# POST /chat     -> chat Lambda
# GET  /history  -> history Lambda
# ============================================================

resource "aws_api_gateway_rest_api" "chatbot_api" {
  name        = "${local.name_prefix}-api"
  description = "REST API for the AI Chatbot - managed by Terraform"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ============================================================
# /chat  - POST
# ============================================================

resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "chat"
}

resource "aws_api_gateway_method" "chat_post" {
  rest_api_id      = aws_api_gateway_rest_api.chatbot_api.id
  resource_id      = aws_api_gateway_resource.chat.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "chat_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chatbot_api.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.chat.invoke_arn
}

# ============================================================
# /history  - GET
# ============================================================

resource "aws_api_gateway_resource" "history" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "history"
}

resource "aws_api_gateway_method" "history_get" {
  rest_api_id      = aws_api_gateway_rest_api.chatbot_api.id
  resource_id      = aws_api_gateway_resource.history.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "history_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chatbot_api.id
  resource_id             = aws_api_gateway_resource.history.id
  http_method             = aws_api_gateway_method.history_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.history.invoke_arn
}

# ============================================================
# Deployment & Stage
# ============================================================

resource "aws_api_gateway_deployment" "chatbot_deploy" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat.id,
      aws_api_gateway_method.chat_post.id,
      aws_api_gateway_integration.chat_integration.id,
      aws_api_gateway_resource.history.id,
      aws_api_gateway_method.history_get.id,
      aws_api_gateway_integration.history_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.chat_post,
    aws_api_gateway_method.history_get
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.chatbot_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  # Must wait for the account-level CloudWatch role to be registered first
  depends_on = [aws_api_gateway_account.main]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      duration       = "$context.responseLatency"
    })
  }
}

# ============================================================
# API Key - clients must send this in x-api-key header
# ============================================================

resource "aws_api_gateway_api_key" "chatbot_key" {
  name        = "${local.name_prefix}-api-key"
  description = "API key for chatbot clients"
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "chatbot_plan" {
  name        = "${local.name_prefix}-usage-plan"
  description = "Throttle and quota limits"

  api_stages {
    api_id = aws_api_gateway_rest_api.chatbot_api.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    burst_limit = 50
    rate_limit  = 20
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }
}

resource "aws_api_gateway_usage_plan_key" "chatbot_plan_key" {
  key_id        = aws_api_gateway_api_key.chatbot_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.chatbot_plan.id
}
