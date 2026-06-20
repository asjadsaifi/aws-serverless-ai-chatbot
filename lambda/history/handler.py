"""
History Lambda Handler
----------------------
Retrieves paginated chat history for a session from DynamoDB.

Industry practices used here:
- Structured JSON logging
- Input validation and sanitisation
- Specific exception handling
- Type hints throughout
"""

import json
import logging
import os
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import BotoCoreError, ClientError

# ---- Logging setup ----
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

# ---- Config from environment ----
DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
AWS_REGION = os.environ["AWS_REGION_NAME"]

# ---- AWS client (reused on warm starts) ----
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

MAX_LIMIT = 100  # Hard cap - prevents oversized responses


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Main Lambda entry point - returns chat history for a session.

    Query params:
        session_id (required) - the conversation to fetch
        limit      (optional) - number of messages (1-100, default 20)
    """
    request_id = context.aws_request_id

    logger.info(json.dumps({
        "message": "History request received",
        "request_id": request_id,
    }))

    try:
        params: dict[str, Any] = event.get("queryStringParameters") or {}
        session_id = (params.get("session_id") or "").strip()

        if not session_id:
            return _response(400, {"error": "session_id query parameter is required"})

        try:
            limit = max(1, min(int(params.get("limit", 20)), MAX_LIMIT))
        except (ValueError, TypeError):
            return _response(400, {"error": "limit must be an integer between 1 and 100"})

        result = table.query(
            KeyConditionExpression=Key("session_id").eq(session_id),
            Limit=limit,
            ScanIndexForward=True,
        )

        messages = result.get("Items", [])

        logger.info(json.dumps({
            "message": "History fetched",
            "request_id": request_id,
            "session_id": session_id,
            "count": len(messages),
        }))

        return _response(200, {
            "session_id": session_id,
            "count": len(messages),
            "messages": messages,
        })

    except ClientError as exc:
        error_code = exc.response["Error"]["Code"]
        logger.error(json.dumps({
            "message": "DynamoDB error",
            "request_id": request_id,
            "error_code": error_code,
            "error": str(exc),
        }))
        return _response(502, {"error": "Database error. Please try again."})

    except (BotoCoreError, ValueError) as exc:
        logger.error(json.dumps({
            "message": "Processing error",
            "request_id": request_id,
            "error": str(exc),
        }))
        return _response(500, {"error": "Internal server error"})


def _response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    """Build an API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "X-Content-Type-Options": "nosniff",
        },
        "body": json.dumps(body, default=str),
    }
