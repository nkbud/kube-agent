"""CLI entry point for kube-agent."""

import uvicorn
from kube_agent.config import Settings


def main() -> None:
    """Run the kube-agent FastAPI application."""
    settings = Settings()
    
    uvicorn.run(
        "kube_agent.main:app",
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level.lower(),
        reload=settings.debug,
    )


if __name__ == "__main__":
    main()