# kube-agent

An AI-powered and MCP-augmented agent that can investigate issues in its own Kubernetes cluster.

## Overview

kube-agent is a FastAPI-based application designed to receive Alertmanager webhooks and provide intelligent analysis of Kubernetes cluster issues. It features:

- **FastAPI REST API** with health, metrics, and alerts endpoints
- **Prometheus metrics** integration for monitoring
- **Alertmanager webhook** processing for real-time alert handling
- **Kubernetes RBAC** integration for cluster resource access
- **Helm chart** for easy deployment
- **CI/CD pipeline** with GitHub Actions
- **Local development** environment with kind and Terraform

## Quick Start

### Prerequisites

- Docker
- kind (Kubernetes in Docker)
- kubectl
- Helm 3
- Terraform
- Python 3.11+ (for local development)

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nkbud/kube-agent.git
   cd kube-agent
   ```

2. **Setup Python environment:**
   ```bash
   # Install uv for fast Python package management
   pip install uv
   
   # Create virtual environment and install dependencies
   uv venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   uv pip install -e ".[dev]"
   ```

3. **Run the application locally:**
   ```bash
   # Run with default settings
   python -m kube_agent.cli
   
   # Or with custom configuration
   KUBE_AGENT_PORT=8080 KUBE_AGENT_LOG_LEVEL=DEBUG python -m kube_agent.cli
   ```

4. **Test the endpoints:**
   ```bash
   # Health check
   curl http://localhost:8000/health
   
   # Prometheus metrics
   curl http://localhost:8000/metrics
   
   # Test alert webhook (example payload)
   curl -X POST http://localhost:8000/alerts \
     -H "Content-Type: application/json" \
     -d @examples/sample-alert.json
   ```

### Docker Build

```bash
# Build the Docker image
docker build -t kube-agent .

# Run with Docker
docker run -p 8000:8000 kube-agent
```

### Kubernetes Deployment with kind

The project includes a complete setup for running kube-agent in a local Kubernetes cluster with monitoring stack:

1. **Setup kind cluster with monitoring:**
   ```bash
   cd kind
   ./setup-cluster.sh setup
   ```

   This will:
   - Create a 3-node kind cluster
   - Deploy kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
   - Deploy kube-agent with Helm
   - Configure Alertmanager to send webhooks to kube-agent
   - Deploy test workloads that trigger alerts

2. **Access the services:**
   ```bash
   # Grafana (admin/admin)
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   # Open http://localhost:3000
   
   # Prometheus
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
   # Open http://localhost:9090
   
   # Alertmanager
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
   # Open http://localhost:9093
   
   # kube-agent
   kubectl port-forward svc/kube-agent 8080:8000
   # Open http://localhost:8080/health
   ```

3. **Monitor kube-agent logs:**
   ```bash
   kubectl logs -l app.kubernetes.io/name=kube-agent -f
   ```

4. **Trigger test alerts:**
   ```bash
   # Force pod restart to trigger PodCrashLooping alert
   kubectl delete pod -l app=failing-app -n test-workloads
   
   # Scale up failing app to trigger more alerts
   kubectl scale deployment failing-app --replicas=3 -n test-workloads
   ```

5. **Cleanup:**
   ```bash
   ./setup-cluster.sh cleanup
   ```

## API Documentation

### Endpoints

- **GET /health** - Health check endpoint
- **GET /metrics** - Prometheus metrics
- **POST /alerts** - Alertmanager webhook endpoint
- **GET /** - API information

### Example Alert Payload

```json
{
  "version": "4",
  "groupKey": "{}:{alertname=\"PodCrashLooping\"}",
  "status": "firing",
  "receiver": "kube-agent",
  "groupLabels": {"alertname": "PodCrashLooping"},
  "commonLabels": {
    "alertname": "PodCrashLooping",
    "severity": "warning",
    "namespace": "test-workloads",
    "pod": "failing-app-xxx"
  },
  "commonAnnotations": {
    "summary": "Pod test-workloads/failing-app-xxx is crash looping",
    "description": "Pod has been restarting frequently"
  },
  "externalURL": "http://alertmanager:9093",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "PodCrashLooping",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Pod is crash looping"
      },
      "startsAt": "2024-01-01T00:00:00Z",
      "fingerprint": "abc123"
    }
  ]
}
```

## Configuration

The application can be configured using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `KUBE_AGENT_HOST` | `0.0.0.0` | Host to bind the server |
| `KUBE_AGENT_PORT` | `8000` | Port to bind the server |
| `KUBE_AGENT_LOG_LEVEL` | `INFO` | Logging level |
| `KUBE_AGENT_DEBUG` | `false` | Enable debug mode |
| `KUBE_AGENT_IN_CLUSTER` | `true` | Running inside Kubernetes cluster |

## Helm Chart

The Helm chart is located in `helm/kube-agent/` and includes:

- Deployment with security context
- Service for internal access
- ServiceAccount with RBAC permissions
- ConfigMaps for configuration
- ServiceMonitor for Prometheus scraping
- Optional Ingress support

### Install with Helm

```bash
# Install from local chart
helm install kube-agent ./helm/kube-agent

# Install with custom values
helm install kube-agent ./helm/kube-agent -f my-values.yaml

# Upgrade
helm upgrade kube-agent ./helm/kube-agent
```

## Development

### Testing

```bash
# Run tests
pytest tests/ -v

# Run tests with coverage
pytest tests/ -v --cov=kube_agent

# Run specific test
pytest tests/test_main.py::test_health_endpoint -v
```

### Linting and Formatting

```bash
# Format code
ruff format .

# Lint code
ruff check .

# Type checking
mypy kube_agent
```

### CI/CD

The project includes GitHub Actions workflows:

- **CI** (`.github/workflows/ci.yml`): Testing, linting, security scanning
- **Build** (`.github/workflows/build.yml`): Docker image building and publishing

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Prometheus    │    │   Alertmanager   │    │   kube-agent    │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │ Alert Rules │ │    │ │ Webhook to   │ │    │ │ FastAPI     │ │
│ │             │ │────▶ │ kube-agent   │ │────▶ │ /alerts     │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └──────────────────┘    │ ┌─────────────┐ │
                                                │ │ Kubernetes  │ │
┌─────────────────┐    ┌──────────────────┐    │ │ API Client  │ │
│    Grafana      │    │ ServiceMonitor   │    │ └─────────────┘ │
│                 │    │                  │    └─────────────────┘
│ ┌─────────────┐ │    │ ┌──────────────┐ │              │
│ │ Dashboards  │ │◀───│ │ Scrape       │ │◀─────────────┘
│ │             │ │    │ │ /metrics     │ │
│ └─────────────┘ │    │ └──────────────┘ │
└─────────────────┘    └──────────────────┘
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass and code is properly formatted
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
