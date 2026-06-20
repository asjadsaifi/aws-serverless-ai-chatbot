# AWS Serverless AI Chatbot

A production-ready serverless chatbot API built with industry best practices.

**Stack:** Python 3.12 · Terraform · Amazon Bedrock · DynamoDB · API Gateway · GitHub Actions

---

## Architecture

```
Developer → GitHub PR → GitHub Actions (test + plan) → merge to main
                                                              ↓
                                              GitHub Actions (deploy to dev)
                                                              ↓
                                              Publish GitHub Release
                                                              ↓
                                              GitHub Actions (deploy to prod)

Request flow:
User → API Gateway (x-api-key) → Lambda (Python) → Amazon Bedrock (AI)
                                        ↕
                                  DynamoDB (chat history)
                                        ↕
                                  CloudWatch (logs + alarms)
```

---

## Industry Best Practices Used

| Practice | How |
|---|---|
| No local deploys | GitHub Actions CI/CD pipeline |
| No hardcoded AWS keys | OIDC federation (keyless auth) |
| Remote Terraform state | S3 backend + DynamoDB lock |
| Least privilege IAM | Separate role per Lambda, minimum permissions |
| Structured logging | JSON logs searchable in CloudWatch Logs Insights |
| Input validation | All inputs validated before processing |
| Auto-expiring data | DynamoDB TTL deletes messages after 30 days |
| Encrypted at rest | DynamoDB server-side encryption enabled |
| Point-in-time recovery | DynamoDB PITR — restore to any second in 35 days |
| Rate limiting | API Gateway throttle + monthly quota |
| Monitoring | CloudWatch alarms on error rate and duration |
| Tests | Unit tests run on every PR and push |
| Code quality | ruff (linting) + mypy (type checking) |

---

## Project Structure

```
aws-serverless-chatbot/
├── .github/
│   └── workflows/
│       ├── deploy.yml      ← CI/CD: test → deploy dev → deploy prod
│       └── pr-check.yml    ← PR: lint + test + terraform plan as comment
├── terraform/
│   ├── backend.tf          ← Remote state in S3
│   ├── main.tf             ← Provider config
│   ├── variables.tf        ← Input variables with validation
│   ├── outputs.tf          ← API URLs, resource names
│   ├── lambda.tf           ← Lambda function definitions
│   ├── api_gateway.tf      ← REST API + API key + throttling
│   ├── dynamodb.tf         ← Chat history table
│   ├── iam.tf              ← Separate least-privilege roles per Lambda
│   ├── cloudwatch.tf       ← Log groups + alarms
│   └── terraform.tfvars.example
├── lambda/
│   ├── chat/
│   │   ├── handler.py      ← Chat handler: validates → Bedrock → DynamoDB
│   │   └── requirements.txt
│   └── history/
│       ├── handler.py      ← History handler: reads DynamoDB
│       └── requirements.txt
├── tests/
│   ├── test_chat_handler.py
│   └── test_history_handler.py
├── pyproject.toml          ← ruff, mypy, pytest config
├── requirements-dev.txt    ← Dev/CI dependencies (not deployed)
└── .gitignore
```

---

## Prerequisites

1. [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
2. [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.7.0
3. [Python 3.12](https://www.python.org/downloads/)
4. Enable Bedrock model access:
   - AWS Console → Bedrock → Model Access → Enable **Titan Text Express**

---

## One-Time Setup

### 1. Create the Terraform remote state bucket

```bash
# Replace YOUR-NAME with something unique (S3 bucket names are global)
aws s3api create-bucket \
  --bucket YOUR-NAME-ai-chatbot-tfstate \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket YOUR-NAME-ai-chatbot-tfstate \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Update `terraform/backend.tf` with your bucket name.

### 2. Set up GitHub OIDC (keyless AWS auth — no access keys)

```bash
# Create an OIDC identity provider for GitHub in your AWS account
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Create an IAM role with a trust policy for your GitHub repo:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/aws-serverless-chatbot:*" }
    }
  }]
}
```

Attach `AdministratorAccess` (or a tighter policy) to this role.

### 3. Add GitHub Secrets

In your GitHub repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of the OIDC role you just created |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | Your S3 bucket name |

### 4. Create GitHub Environments

In Settings → Environments, create two environments: `dev` and `prod`.  
For `prod`, add a required reviewer — this means prod deploys need manual approval.

---

## Local Development

```bash
# Install dev dependencies
pip install -r requirements-dev.txt

# Run tests
pytest

# Lint
ruff check lambda/

# Type check
mypy lambda/ --ignore-missing-imports
```

For local Terraform work (optional, use sparingly):

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values
cd terraform
terraform init
terraform plan
```

---

## Deployment Flow

```
feature branch → PR → tests run + terraform plan posted as comment
                   ↓ merge to main
             deploy-dev job runs automatically
                   ↓ create GitHub Release
             deploy-prod job runs (requires manual approval if configured)
```

---

## API Usage

After deploy, Terraform outputs your API URL. Get your API key:

```bash
# Get the key value (Terraform outputs the key ID)
aws apigateway get-api-key \
  --api-key <key-id-from-terraform-output> \
  --include-value \
  --query "value" --output text
```

```bash
# Send a message
curl -X POST https://<api-url>/dev/chat \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"session_id": "test-123", "message": "What is AWS Lambda?"}'

# Get chat history
curl "https://<api-url>/dev/history?session_id=test-123" \
  -H "x-api-key: YOUR_API_KEY"
```

---

## Tear Down

```bash
cd terraform
terraform destroy -var="environment=dev"
```

---

## Cost Estimate

| Service | Free Tier | Notes |
|---|---|---|
| Lambda | 1M requests/month | Free |
| API Gateway | 1M calls/month | Free |
| DynamoDB | 25 GB storage | Free |
| Bedrock (Titan) | None | ~$0.0008 per 1K input tokens |
| CloudWatch Logs | 5 GB/month | Free |

Typical dev usage: **< $1/month**
