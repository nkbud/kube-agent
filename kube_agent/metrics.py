"""Prometheus metrics for kube-agent."""

import time
from prometheus_client import Counter, Histogram, Info, generate_latest, CONTENT_TYPE_LATEST
from prometheus_client import CollectorRegistry, multiprocess, generate_latest as mp_generate_latest


# Create metrics registry
registry = CollectorRegistry()

# Application info
app_info = Info(
    'kube_agent_info',
    'Information about kube-agent application',
    registry=registry
)

# Request metrics
http_requests_total = Counter(
    'kube_agent_http_requests_total',
    'Total number of HTTP requests',
    ['method', 'endpoint', 'status_code'],
    registry=registry
)

http_request_duration_seconds = Histogram(
    'kube_agent_http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    registry=registry
)

# Alert processing metrics
alerts_received_total = Counter(
    'kube_agent_alerts_received_total',
    'Total number of alerts received',
    ['alert_name', 'severity'],
    registry=registry
)

alerts_processed_total = Counter(
    'kube_agent_alerts_processed_total',
    'Total number of alerts processed',
    ['alert_name', 'status'],
    registry=registry
)


def init_metrics() -> None:
    """Initialize application metrics."""
    app_info.info({
        'version': '0.1.0',
        'description': 'AI-powered Kubernetes cluster investigation agent'
    })


def get_metrics() -> str:
    """Get Prometheus metrics in text format."""
    return generate_latest(registry).decode('utf-8')