# ============================================================
# Remote Backend Configuration
# ============================================================
# Stores Terraform state in S3 instead of your local machine.
# This is REQUIRED for team work — everyone reads the same state.
#
# SETUP (one-time, before first terraform init):
#   1. Create an S3 bucket:
#      aws s3api create-bucket --bucket <your-unique-name>-tfstate --region us-east-1
#
#   2. Enable versioning (lets you roll back bad state):
#      aws s3api put-bucket-versioning \
#        --bucket <your-unique-name>-tfstate \
#        --versioning-configuration Status=Enabled
#
#   3. Create DynamoDB table for state locking (prevents two people deploying at once):
#      aws dynamodb create-table \
#        --table-name terraform-state-lock \
#        --attribute-definitions AttributeName=LockID,AttributeType=S \
#        --key-schema AttributeName=LockID,KeyType=HASH \
#        --billing-mode PAY_PER_REQUEST
#
#   4. Replace the bucket name below with your bucket name.
# ============================================================

terraform {
  backend "s3" {
    bucket         = "asjad-ai-chatbot-tfstate"
    key            = "ai-chatbot/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true                       # Encrypt state at rest
    dynamodb_table = "terraform-state-lock"     # Prevents concurrent applies
  }
}
