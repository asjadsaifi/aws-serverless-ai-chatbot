# ============================================================
# IAM - Least Privilege Principle
# ============================================================
# Each Lambda gets ONLY the permissions it needs.
# chat Lambda    -> Bedrock + DynamoDB write + CloudWatch logs
# history Lambda -> DynamoDB read only + CloudWatch logs
# ============================================================

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ============================================================
# Chat Lambda Role - needs Bedrock + DynamoDB write
# ============================================================

resource "aws_iam_role" "chat_lambda_role" {
  name               = "${local.name_prefix}-chat-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  description        = "Role for the chat Lambda - Bedrock + DynamoDB write"
}

resource "aws_iam_role_policy_attachment" "chat_lambda_logs" {
  role       = aws_iam_role.chat_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "chat_lambda_policy" {
  name = "${local.name_prefix}-chat-lambda-policy"
  role = aws_iam_role.chat_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:Converse"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
      },
      {
        Sid    = "AllowDynamoDBWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.chat_history.arn
      }
    ]
  })
}

# ============================================================
# History Lambda Role - read-only DynamoDB (no Bedrock needed)
# ============================================================

resource "aws_iam_role" "history_lambda_role" {
  name               = "${local.name_prefix}-history-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  description        = "Role for the history Lambda - DynamoDB read only"
}

resource "aws_iam_role_policy_attachment" "history_lambda_logs" {
  role       = aws_iam_role.history_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "history_lambda_policy" {
  name = "${local.name_prefix}-history-lambda-policy"
  role = aws_iam_role.history_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynamoDBReadOnly"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.chat_history.arn
      }
    ]
  })
}
