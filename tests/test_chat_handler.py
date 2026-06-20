"""
Unit tests for the chat Lambda handler.
All AWS clients are mocked so tests run with zero AWS access.
"""

import importlib
import json
import os
from unittest.mock import MagicMock, patch

import pytest

# Set required environment variables before importing the handler
os.environ.setdefault("DYNAMODB_TABLE", "test-table")
os.environ.setdefault("BEDROCK_MODEL_ID", "amazon.nova-micro-v1:0")
os.environ.setdefault("AWS_REGION_NAME", "us-east-1")


class FakeLambdaContext:
    aws_request_id = "test-request-id-123"


@pytest.fixture()
def mock_aws():
    """Patch boto3 resource and client before importing handler."""
    mock_table = MagicMock()
    mock_bedrock = MagicMock()

    # Mock Bedrock Converse API response
    mock_bedrock.converse.return_value = {
        "output": {
            "message": {
                "content": [{"text": "Hello! I am an AI assistant."}]
            }
        }
    }

    with patch("boto3.resource") as mock_resource, \
         patch("boto3.client") as mock_client:

        mock_resource.return_value.Table.return_value = mock_table
        mock_client.return_value = mock_bedrock

        import src.chat.handler as handler
        importlib.reload(handler)

        yield handler, mock_table, mock_bedrock


def make_event(body: dict) -> dict:
    """Build a minimal API Gateway proxy event."""
    return {
        "httpMethod": "POST",
        "path": "/chat",
        "body": json.dumps(body),
        "queryStringParameters": None,
    }


def test_successful_chat(mock_aws):
    handler, mock_table, _ = mock_aws
    event = make_event({"session_id": "sess-1", "message": "Hello!"})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["session_id"] == "sess-1"
    assert "response" in body
    assert mock_table.put_item.call_count == 2  # user + assistant saved


def test_missing_message_returns_400(mock_aws):
    handler, _, _ = mock_aws
    event = make_event({"session_id": "sess-1"})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 400
    assert "error" in json.loads(response["body"])


def test_empty_message_returns_400(mock_aws):
    handler, _, _ = mock_aws
    event = make_event({"message": "   "})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 400


def test_message_too_long_returns_400(mock_aws):
    handler, _, _ = mock_aws
    event = make_event({"message": "x" * 4001})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 400


def test_auto_generates_session_id_if_missing(mock_aws):
    handler, _, _ = mock_aws
    event = make_event({"message": "Hello!"})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 200
    assert len(json.loads(response["body"])["session_id"]) > 0


def test_invalid_json_body_returns_500(mock_aws):
    handler, _, _ = mock_aws
    event = {
        "httpMethod": "POST",
        "path": "/chat",
        "body": "NOT VALID JSON",
        "queryStringParameters": None,
    }

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 500


def test_cors_header_present(mock_aws):
    handler, _, _ = mock_aws
    event = make_event({"message": "Hello!"})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["headers"]["Access-Control-Allow-Origin"] == "*"
