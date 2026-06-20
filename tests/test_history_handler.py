"""
Unit tests for the history Lambda handler.
"""

import json
import os
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DYNAMODB_TABLE", "test-table")
os.environ.setdefault("AWS_REGION_NAME", "us-east-1")


class FakeLambdaContext:
    aws_request_id = "test-request-id-456"


def make_event(params: dict) -> dict:
    return {
        "httpMethod": "GET",
        "path": "/history",
        "queryStringParameters": params,
    }


@pytest.fixture()
def mock_aws(monkeypatch):
    mock_table = MagicMock()
    mock_table.query.return_value = {
        "Items": [
            {"session_id": "sess-1", "timestamp": "2024-01-01T00:00:00", "role": "user", "content": "Hi"},
            {"session_id": "sess-1", "timestamp": "2024-01-01T00:00:01", "role": "assistant", "content": "Hello!"},
        ]
    }

    with patch("boto3.resource") as mock_resource:
        mock_resource.return_value.Table.return_value = mock_table

        import importlib
        import lambda.history.handler as handler
        importlib.reload(handler)

        yield handler, mock_table


def test_returns_history(mock_aws):
    handler, _ = mock_aws
    event = make_event({"session_id": "sess-1"})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["count"] == 2
    assert len(body["messages"]) == 2


def test_missing_session_id_returns_400(mock_aws):
    handler, _ = mock_aws
    event = make_event({})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 400


def test_none_query_params_returns_400(mock_aws):
    handler, _ = mock_aws
    event = {"httpMethod": "GET", "path": "/history", "queryStringParameters": None}

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 400


def test_invalid_limit_returns_400(mock_aws):
    handler, _ = mock_aws
    event = make_event({"session_id": "sess-1", "limit": "abc"})

    response = handler.lambda_handler(event, FakeLambdaContext())

    assert response["statusCode"] == 400


def test_limit_is_capped_at_100(mock_aws):
    handler, mock_table = mock_aws
    event = make_event({"session_id": "sess-1", "limit": "9999"})

    handler.lambda_handler(event, FakeLambdaContext())

    call_kwargs = mock_table.query.call_args.kwargs
    assert call_kwargs["Limit"] == 100
