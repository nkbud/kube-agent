"""Pydantic models for kube-agent."""

from datetime import UTC, datetime

from pydantic import BaseModel, Field


class AlertLabel(BaseModel):
    """Alert label model."""

    pass


class AlertAnnotation(BaseModel):
    """Alert annotation model."""

    pass


class Alert(BaseModel):
    """Alertmanager alert model."""

    status: str
    labels: dict[str, str]
    annotations: dict[str, str]
    startsAt: str
    endsAt: str | None = None
    generatorURL: str | None = None
    fingerprint: str | None = None


class AlertmanagerWebhook(BaseModel):
    """Alertmanager webhook payload model."""

    version: str
    groupKey: str
    truncatedAlerts: int = 0
    status: str
    receiver: str
    groupLabels: dict[str, str]
    commonLabels: dict[str, str]
    commonAnnotations: dict[str, str]
    externalURL: str
    alerts: list[Alert]


class HealthResponse(BaseModel):
    """Health check response model."""

    status: str = "healthy"
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))
    version: str = "0.1.0"
    uptime_seconds: float | None = None


class AlertProcessingResponse(BaseModel):
    """Alert processing response model."""

    status: str = "received"
    alert_count: int
    processed_alerts: list[str] = Field(default_factory=list)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))
