# ============================================================
# Amazon Cognito — User Authentication
# ============================================================
# Cognito handles sign-up, sign-in, JWT tokens.
# API Gateway validates the JWT on every request.
# No more shared API key — each user has their own identity.
# ============================================================

resource "aws_cognito_user_pool" "chatbot" {
  name = "${local.name_prefix}-users"

  # Users sign in with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Send verification emails via Cognito (free tier)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    string_attribute_constraints {
      min_length = 5
      max_length = 254
    }
  }

  tags = {
    Name = "${local.name_prefix}-users"
  }
}

# App client — used by the frontend to authenticate
resource "aws_cognito_user_pool_client" "frontend" {
  name         = "${local.name_prefix}-frontend-client"
  user_pool_id = aws_cognito_user_pool.chatbot.id

  # No client secret — public SPA client
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Token validity
  access_token_validity  = 1   # 1 hour
  id_token_validity      = 1   # 1 hour
  refresh_token_validity = 30  # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}

# Cognito Domain — hosted UI for sign-in (optional but useful)
resource "aws_cognito_user_pool_domain" "chatbot" {
  domain       = "${local.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.chatbot.id
}
