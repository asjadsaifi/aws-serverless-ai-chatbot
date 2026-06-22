# ============================================================
# Lambda Functions
# ============================================================
# Each function has its own IAM role (least privilege).
# source_code_hash ensures Lambda updates whenever code changes.
# ============================================================

data "archive_file" "chat_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/chat"
  output_path = "${path.module}/../.builds/chat.zip"
}

data "archive_file" "history_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/history"
  output_path = "${path.module}/../.builds/history.zip"
}

# ---- Chat Lambda ----
resource "aws_lambda_function" "chat" {
  function_name    = "${local.name_prefix}-chat"
  role             = aws_iam_role.chat_lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.chat_lambda_zip.output_path
  source_code_hash = data.archive_file.chat_lambda_zip.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  depends_on = [aws_cloudwatch_log_group.chat_lambda]

  environment {
    variables = {
      DYNAMODB_TABLE   = aws_dynamodb_table.chat_history.name
      BEDROCK_MODEL_ID = var.bedrock_model_id
      AWS_REGION_NAME  = var.aws_region
      LOG_LEVEL        = var.environment == "prod" ? "WARNING" : "DEBUG"
      CONTEXT_WINDOW   = "10"
    }
  }
}

# ---- History Lambda ----
resource "aws_lambda_function" "history" {
  function_name    = "${local.name_prefix}-history"
  role             = aws_iam_role.history_lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.history_lambda_zip.output_path
  source_code_hash = data.archive_file.history_lambda_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  depends_on = [aws_cloudwatch_log_group.history_lambda]

  environment {
    variables = {
      DYNAMODB_TABLE  = aws_dynamodb_table.chat_history.name
      AWS_REGION_NAME = var.aws_region
      LOG_LEVEL       = var.environment == "prod" ? "WARNING" : "DEBUG"
    }
  }
}

resource "aws_lambda_permission" "chat_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "history_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.history.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*"
}
