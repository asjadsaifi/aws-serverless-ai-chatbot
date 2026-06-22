# ============================================================
# Outputs - printed after terraform apply
# ============================================================

output "api_base_url" {
  description = "Base URL for the chatbot API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "chat_endpoint" {
  description = "POST to this URL to send a message (requires Authorization: Bearer <jwt>)"
  value       = "${aws_api_gateway_stage.main.invoke_url}/chat"
}

output "history_endpoint" {
  description = "GET from this URL to retrieve chat history (requires Authorization: Bearer <jwt>)"
  value       = "${aws_api_gateway_stage.main.invoke_url}/history"
}

output "dynamodb_table_name" {
  description = "DynamoDB chat history table name"
  value       = aws_dynamodb_table.chat_history.name
}

output "chat_lambda_name" {
  description = "Chat Lambda function name"
  value       = aws_lambda_function.chat.function_name
}

output "history_lambda_name" {
  description = "History Lambda function name"
  value       = aws_lambda_function.history.function_name
}

# Cognito outputs - needed by frontend configuration
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.chatbot.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.frontend.id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = "${aws_cognito_user_pool_domain.chatbot.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "frontend_bucket_name" {
  description = "S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_url" {
  description = "CloudFront URL for the frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
