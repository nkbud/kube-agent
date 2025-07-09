"""Tests for the main FastAPI application."""

import pytest
from fastapi.testclient import TestClient
from kube_agent.main import app


@pytest.fixture
def client() -> TestClient:
    """Create a test client for the FastAPI app."""
    return TestClient(app)


def test_root_endpoint(client: TestClient) -> None:
    """Test the root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "kube-agent"
    assert data["version"] == "0.1.0"
    assert "endpoints" in data


def test_health_endpoint(client: TestClient) -> None:
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["version"] == "0.1.0"
    assert "uptime_seconds" in data
    assert "timestamp" in data


def test_metrics_endpoint(client: TestClient) -> None:
    """Test the Prometheus metrics endpoint."""
    response = client.get("/metrics")
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/plain; charset=utf-8"
    assert "kube_agent_info" in response.text


def test_alerts_endpoint(client: TestClient) -> None:
    """Test the alerts webhook endpoint."""
    # Sample Alertmanager webhook payload
    payload = {
        "version": "4",
        "groupKey": "{}:{alertname=\"TestAlert\"}",
        "truncatedAlerts": 0,
        "status": "firing",
        "receiver": "kube-agent",
        "groupLabels": {"alertname": "TestAlert"},
        "commonLabels": {"alertname": "TestAlert", "severity": "warning"},
        "commonAnnotations": {"summary": "Test alert"},
        "externalURL": "http://alertmanager:9093",
        "alerts": [
            {
                "status": "firing",
                "labels": {"alertname": "TestAlert", "severity": "warning"},
                "annotations": {"summary": "Test alert"},
                "startsAt": "2024-01-01T00:00:00Z",
                "fingerprint": "test123"
            }
        ]
    }
    
    response = client.post("/alerts", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "processed"
    assert data["alert_count"] == 1
    assert "TestAlert" in data["processed_alerts"]