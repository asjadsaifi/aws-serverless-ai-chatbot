"""
Chat Lambda Handler
-------------------
Receives a user message, calls Amazon Bedrock for an AI response,
stores both in DynamoDB, and returns the reply.

Industry practices used here:
- Structured JSON logging (searchable in CloudWatch Logs Insights)
- Input validation with clear error messages
- AWS clients initialized outside handler (connection reuse on warm starts)
- Specific exception handling — not bare except
- Environment-driven log level
"""

import json
import logging
import os
import uuid
from datetime import datetime, timedelta

import boto3
from botocore.exceptions import BotoCoreError, ClientError

# ---- Logging setup ----
# Structured JSON logs are searchable in CloudWatch Logs Insights.
# Set LOG_LEVEL=DEBUG in dev, WARNING in prod via Terraform environment variables.
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

# ---- Config from environment (set by Terraform) ----
DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
BEDROCK_MODEL_ID = os.environ["BEDROCK_MODEL_ID"]
AWS_REGION = os.environ["AWS_REGION_NAME"]

# ---- AWS clients (initialized once, reused on warm Lambda starts) ----
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
bedrock = boto3.client("bedrock-runtime", region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)


def lambda_handler(event: dict, context) -> dict:
    """
    Main Lambda entry point called by API Gateway.

    Args:
        event:   API Gateway proxy event
        context: Lambda context object

    Returns:
        API Gateway proxy response dict
    """
    request_id = context.aws_request_id

    logger.info(json.dumps({
        "message": "Request received",
        "request_id": request_id,
        "http_method": event.get("httpMethod"),
        "path": event.get("path"),
    }))

    try:
        body = _parse_body(event)
        session_id = body.get("session_id") or str(uuid.uuid4())
        user_message = body.get("message", "").strip()

        if not user_message:
            return _response(400, {"error": "message field is required and cannot be empty"})

        if len(user_message) > 4000:
            return _response(400, {"error": "message exceeds maximum length of 4000 characters"})

        # Call Bedrock for an AI response
        ai_response = _invoke_bedrock(user_message, request_id)

        # Persist both turns to DynamoDB
        _save_message(session_id, "user", user_message)
        _save_message(session_id, "assistant", ai_response)

        logger.info(json.dumps({
            "message": "Request completed successfully",
            "request_id": request_id,
            "session_id": session_id,
        }))

        return _response(200, {
            "session_id": session_id,
            "response": ai_response,
        })

    except ClientError as exc:
        error_code = exc.response["Error"]["Code"]
        logger.error(json.dumps({
            "message": "AWS service error",
            "request_id": request_id,
            "error_code": error_code,
            "error": str(exc),
        }))
        return _response(502, {"error": "Upstream service error. Please try again."})

    except (BotoCoreError, ValueError) as exc:
        logger.error(json.dumps({
            "message": "Processing error",
            "request_id": request_id,
            "error": str(exc),
        }))
        return _response(500, {"error": "Internal server error"})


def _parse_body(event: dict) -> dict:
    """Safely parse the request body, returning empty dict on failure."""
    raw_body = event.get("body") or "{}"
    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON body: {exc}") from exc


def _invoke_bedrock(message: str, request_id: str) -> str:
    """
    Send a message to Amazon Bedrock Nova Lite and return the reply.
    Uses the Converse API — works with any Bedrock model, future-proof.

    Raises:
        ClientError: if Bedrock call fails
    """
    logger.debug(json.dumps({
        "message": "Invoking Bedrock",
        "request_id": request_id,
        "model_id": BEDROCK_MODEL_ID,
    }))

    # Converse API — single unified format that works across all Bedrock models
    response = bedrock.converse(
        modelId=BEDROCK_MODEL_ID,
        messages=[
            {
                "role": "user",
                "content": [{"text": message}],
            }
        ],
        inferenceConfig={
            "maxTokens": 512,
            "temperature": 0.7,
            "topP": 0.9,
        },
    )

    return response["output"]["message"]["content"][0]["text"].strip()


def _save_message(session_id: str, role: str, content: str) -> None:
    """
    Persist a single chat message to DynamoDB with a 30-day TTL.

    Args:
        session_id: unique identifier for this conversation
        role:       "user" or "assistant"
        content:    message text
    """
    now = datetime.now(datetime.UTC)
    expires_at = int((now + timedelta(days=30)).timestamp())

    table.put_item(Item={
        "session_id": session_id,
        "timestamp": now.isoformat(),
        "role": role,
        "content": content,
        "expires_at": expires_at,
    })


def _response(status_code: int, body: dict) -> dict:
    """Build an API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "X-Content-Type-Options": "nosniff",
        },
        "body": json.dumps(body),
    }
