"""Configuration settings for kube-agent."""

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""

    app_name: str = "kube-agent"
    app_version: str = "0.1.0"
    debug: bool = Field(default=False, description="Enable debug mode")
    host: str = Field(default="0.0.0.0", description="Host to bind the server")
    port: int = Field(default=8000, description="Port to bind the server")
    log_level: str = Field(default="INFO", description="Logging level")

    # Kubernetes settings
    in_cluster: bool = Field(
        default=True, description="Running inside Kubernetes cluster"
    )

    model_config = {"env_prefix": "KUBE_AGENT_"}
