# ============================================================
# Outputs — printed after terraform apply
# ============================================================

output "api_base_url" {
  description = "Base URL for the chatbot API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "chat_endpoint" {
  description = "POST to this URL to send a message (requires x-api-key header)"
  value       = "${aws_api_gateway_stage.main.invoke_url}/chat"
}

output "history_endpoint" {
  description = "GET from this URL to retrieve chat history (requires x-api-key header)"
  value       = "${aws_api_gateway_stage.main.invoke_url}/history"
}

output "api_key_id" {
  description = "API Key ID — retrieve the value with: aws apigateway get-api-key --api-key <id> --include-value"
  value       = aws_api_gateway_api_key.chatbot_key.id
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
