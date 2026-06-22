"""
Chat Lambda Handler
-------------------
Receives a user message, fetches conversation history from DynamoDB,
sends full context to Amazon Bedrock, stores the reply, returns it.

Industry practices:
- Conversation context (last 10 messages sent to Bedrock)
- Structured JSON logging
- Input validation
- Specific exception handling
- Type hints throughout
"""

import json
import logging
import os
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import BotoCoreError, ClientError

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
BEDROCK_MODEL_ID = os.environ["BEDROCK_MODEL_ID"]
AWS_REGION = os.environ["AWS_REGION_NAME"]
# How many previous messages to include as context (keep costs low)
CONTEXT_WINDOW = int(os.environ.get("CONTEXT_WINDOW", "10"))

dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
bedrock = boto3.client("bedrock-runtime", region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Main Lambda entry point called by API Gateway."""
    request_id = context.aws_request_id

    logger.info(json.dumps({
        "message": "Request received",
        "request_id": request_id,
        "http_method": event.get("httpMethod"),
    }))

    try:
        body = _parse_body(event)
        session_id = body.get("session_id") or str(uuid.uuid4())
        user_message = body.get("message", "").strip()
        system_prompt = body.get("system_prompt", "You are a helpful AI assistant.")

        if not user_message:
            return _response(400, {"error": "message field is required and cannot be empty"})

        if len(user_message) > 4000:
            return _response(400, {"error": "message exceeds maximum length of 4000 characters"})

        # Fetch previous messages to give Bedrock conversation context
        history = _get_history(session_id)

        # Call Bedrock with full conversation context
        ai_response = _invoke_bedrock(user_message, history, system_prompt, request_id)

        # Persist both turns
        _save_message(session_id, "user", user_message)
        _save_message(session_id, "assistant", ai_response)

        logger.info(json.dumps({
            "message": "Request completed",
            "request_id": request_id,
            "session_id": session_id,
            "context_messages": len(history),
        }))

        return _response(200, {
            "session_id": session_id,
            "response": ai_response,
            "context_used": len(history),
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


def _get_history(session_id: str) -> list[dict[str, Any]]:
    """
    Fetch the last CONTEXT_WINDOW messages from DynamoDB.
    Returns them in Bedrock Converse API format.
    """
    result = table.query(
        KeyConditionExpression=Key("session_id").eq(session_id),
        Limit=CONTEXT_WINDOW,
        ScanIndexForward=False,  # Latest first
    )
    items = result.get("Items", [])
    items.reverse()  # Restore chronological order

    # Convert to Bedrock Converse message format
    messages = []
    for item in items:
        role = item.get("role", "user")
        if role in ("user", "assistant"):
            messages.append({
                "role": role,
                "content": [{"text": str(item.get("content", ""))}],
            })
    return messages


def _invoke_bedrock(
    message: str,
    history: list[dict[str, Any]],
    system_prompt: str,
    request_id: str,
) -> str:
    """Send conversation history + new message to Bedrock, return reply."""
    logger.debug(json.dumps({
        "message": "Invoking Bedrock",
        "request_id": request_id,
        "model_id": BEDROCK_MODEL_ID,
        "history_length": len(history),
    }))

    # Append the new user message to history
    messages = history + [{"role": "user", "content": [{"text": message}]}]

    response = bedrock.converse(
        modelId=BEDROCK_MODEL_ID,
        system=[{"text": system_prompt}],
        messages=messages,
        inferenceConfig={
            "maxTokens": 512,
            "temperature": 0.7,
            "topP": 0.9,
        },
    )

    return str(response["output"]["message"]["content"][0]["text"]).strip()


def _save_message(session_id: str, role: str, content: str) -> None:
    """Persist a message to DynamoDB with 30-day TTL."""
    now = datetime.now(UTC)
    expires_at = int((now + timedelta(days=30)).timestamp())

    table.put_item(Item={
        "session_id": session_id,
        "timestamp": now.isoformat(),
        "role": role,
        "content": content,
        "expires_at": expires_at,
    })


def _parse_body(event: dict[str, Any]) -> dict[str, Any]:
    """Safely parse the JSON request body."""
    raw_body = event.get("body") or "{}"
    try:
        result: dict[str, Any] = json.loads(raw_body)
        return result
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON body: {exc}") from exc


def _response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    """Build an API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Api-Key,Authorization",
            "Access-Control-Allow-Methods": "POST,GET,OPTIONS",
            "X-Content-Type-Options": "nosniff",
        },
        "body": json.dumps(body),
    }
