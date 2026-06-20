# ============================================================
# DynamoDB — Chat History Table
# ============================================================

resource "aws_dynamodb_table" "chat_history" {
  name         = "${local.name_prefix}-chat-history"
  billing_mode = "PAY_PER_REQUEST"  # On-demand — no capacity planning needed
  hash_key     = "session_id"
  range_key    = "timestamp"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # Auto-delete messages after N days via TTL
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Enable point-in-time recovery — lets you restore to any second in the last 35 days
  # This is an industry must-have for production tables
  point_in_time_recovery {
    enabled = true
  }

  # Encrypt table at rest using AWS managed key
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${local.name_prefix}-chat-history"
  }
}
