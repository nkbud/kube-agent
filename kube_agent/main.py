"""Main FastAPI application for kube-agent."""

import time
from collections.abc import AsyncGenerator, Awaitable, Callable
from contextlib import asynccontextmanager
from typing import Any

import structlog
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse

from kube_agent.config import Settings
from kube_agent.metrics import (
    alerts_processed_total,
    alerts_received_total,
    get_metrics,
    http_request_duration_seconds,
    http_requests_total,
    init_metrics,
)
from kube_agent.models import (
    AlertmanagerWebhook,
    AlertProcessingResponse,
    HealthResponse,
)

# Initialize structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Application startup time
startup_time = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan manager."""
    # Startup
    logger.info("Starting kube-agent application")
    init_metrics()
    yield
    # Shutdown
    logger.info("Shutting down kube-agent application")


# Initialize FastAPI app
settings = Settings()
app = FastAPI(
    title="Kube Agent",
    description="AI-powered Kubernetes cluster investigation agent",
    version=settings.app_version,
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def metrics_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """Middleware to collect HTTP metrics."""
    start_time = time.time()

    # Process the request
    response = await call_next(request)

    # Record metrics
    duration = time.time() - start_time
    method = request.method
    path = request.url.path
    status_code = str(response.status_code)

    http_requests_total.labels(
        method=method, endpoint=path, status_code=status_code
    ).inc()

    http_request_duration_seconds.labels(method=method, endpoint=path).observe(duration)

    return response


@app.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Health check endpoint."""
    uptime = time.time() - startup_time
    logger.info("Health check requested", uptime_seconds=uptime)

    return HealthResponse(
        status="healthy", uptime_seconds=uptime, version=settings.app_version
    )


@app.get("/metrics", response_class=PlainTextResponse)
async def get_prometheus_metrics() -> str:
    """Prometheus metrics endpoint."""
    logger.debug("Metrics requested")
    return get_metrics()


@app.post("/alerts", response_model=AlertProcessingResponse)
async def receive_alerts(webhook: AlertmanagerWebhook) -> AlertProcessingResponse:
    """Receive and process Alertmanager webhooks."""
    logger.info(
        "Received alertmanager webhook",
        status=webhook.status,
        alert_count=len(webhook.alerts),
        group_key=webhook.groupKey,
        receiver=webhook.receiver,
    )

    processed_alerts = []

    for alert in webhook.alerts:
        alert_name = alert.labels.get("alertname", "unknown")
        severity = alert.labels.get("severity", "unknown")

        # Record alert metrics
        alerts_received_total.labels(alert_name=alert_name, severity=severity).inc()

        logger.info(
            "Processing alert",
            alert_name=alert_name,
            severity=severity,
            status=alert.status,
            starts_at=alert.startsAt,
            fingerprint=alert.fingerprint,
        )

        # TODO: Implement actual alert processing logic
        # For now, just log and mark as processed
        processed_alerts.append(alert_name)

        alerts_processed_total.labels(alert_name=alert_name, status="processed").inc()

    return AlertProcessingResponse(
        status="processed",
        alert_count=len(webhook.alerts),
        processed_alerts=processed_alerts,
    )


@app.get("/")
async def root() -> dict[str, Any]:
    """Root endpoint with basic application info."""
    return {
        "name": "kube-agent",
        "version": settings.app_version,
        "description": "AI-powered Kubernetes cluster investigation agent",
        "endpoints": {"health": "/health", "metrics": "/metrics", "alerts": "/alerts"},
    }
