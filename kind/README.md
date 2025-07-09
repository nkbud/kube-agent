# kind Cluster Setup Guide

This guide walks you through setting up a complete kube-agent demonstration environment using kind (Kubernetes in Docker).

## What Gets Deployed

The setup script creates:

1. **3-node kind cluster** with port mappings for external access
2. **kube-prometheus-stack** including:
   - Prometheus (metrics collection)
   - Alertmanager (alert routing)
   - Grafana (visualization)
   - Node Exporter (node metrics)
   - Kube State Metrics (Kubernetes metrics)
3. **kube-agent** deployed via Helm with RBAC permissions
4. **Test workloads** that intentionally trigger alerts
5. **Custom PrometheusRules** for demo scenarios
6. **NGINX Ingress Controller** (optional)

## Prerequisites Installation

### macOS (using Homebrew)
```bash
# Install required tools
brew install kind kubectl helm terraform docker

# Start Docker Desktop
open -a Docker
```

### Linux (Ubuntu/Debian)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Windows (using Chocolatey)
```powershell
# Install Chocolatey first: https://chocolatey.org/install

# Install required tools
choco install kind kubectl kubernetes-helm terraform docker-desktop

# Start Docker Desktop manually
```

## Quick Setup

1. **Clone and navigate to the repository:**
   ```bash
   git clone https://github.com/nkbud/kube-agent.git
   cd kube-agent/kind
   ```

2. **Run the setup script:**
   ```bash
   ./setup-cluster.sh setup
   ```

   This process takes about 5-10 minutes depending on your internet connection.

3. **Verify the deployment:**
   ```bash
   # Check cluster status
   kubectl get nodes
   kubectl get pods --all-namespaces
   
   # Check kube-agent is running
   kubectl get pods -l app.kubernetes.io/name=kube-agent
   ```

## Accessing Services

### Port Forwarding (Recommended for Development)

```bash
# Grafana (username: admin, password: admin)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
open http://localhost:3000

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
open http://localhost:9090

# Alertmanager  
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &
open http://localhost:9093

# kube-agent
kubectl port-forward svc/kube-agent 8080:8000 &
curl http://localhost:8080/health
```

### NodePort Access (Alternative)

If you configured NodePort services, you can access them directly:

```bash
# Grafana (if NodePort is configured)
open http://localhost:30000

# NGINX Ingress HTTP
open http://localhost:30001

# NGINX Ingress HTTPS  
open https://localhost:30002
```

## Monitoring kube-agent

### View Logs
```bash
# Follow kube-agent logs
kubectl logs -l app.kubernetes.io/name=kube-agent -f

# View recent logs
kubectl logs -l app.kubernetes.io/name=kube-agent --tail=50
```

### Check Metrics
```bash
# Port forward to kube-agent
kubectl port-forward svc/kube-agent 8080:8000 &

# View metrics
curl http://localhost:8080/metrics

# Check health
curl http://localhost:8080/health | jq
```

### Send Test Alert
```bash
# Send a sample alert to kube-agent
curl -X POST http://localhost:8080/alerts \
  -H "Content-Type: application/json" \
  -d @../examples/sample-alert.json
```

## Triggering Demo Alerts

The setup includes test workloads that automatically trigger alerts:

### 1. Pod Crash Loop Alert
```bash
# The failing-app deployment automatically crashes every 30 seconds
# You can force more restarts:
kubectl delete pod -l app=failing-app -n test-workloads

# Scale up for more alerts:
kubectl scale deployment failing-app --replicas=3 -n test-workloads
```

### 2. High Memory Usage Alert
```bash
# The high-memory-app consumes memory gradually
# Check its resource usage:
kubectl top pod -n test-workloads
kubectl describe pod -l app=high-memory-app -n test-workloads
```

### 3. Custom Alerts
The setup includes custom PrometheusRules that will trigger alerts for:
- Pod crash looping (restarts > 0 in 5m)
- High memory usage (>80% of limit for 2m)
- kube-agent down (service unavailable for 1m)

## Troubleshooting

### Common Issues

1. **"kind cluster already exists"**
   ```bash
   kind delete cluster --name kube-agent-demo
   ./setup-cluster.sh setup
   ```

2. **"Docker not running"**
   ```bash
   # Start Docker Desktop or Docker daemon
   sudo systemctl start docker  # Linux
   ```

3. **"Port already in use"**
   ```bash
   # Kill processes using the ports
   sudo lsof -ti:3000,8080,9090,9093 | xargs kill -9
   ```

4. **Terraform apply fails**
   ```bash
   cd terraform
   terraform destroy -auto-approve
   cd ..
   ./setup-cluster.sh setup
   ```

5. **Pods stuck in Pending**
   ```bash
   # Check node resources
   kubectl describe nodes
   kubectl top nodes
   ```

### Debug Commands

```bash
# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Check service endpoints
kubectl get endpoints

# Check ingress status
kubectl get ingress --all-namespaces

# View Terraform state
cd terraform && terraform show
```

## Cleanup

### Quick Cleanup
```bash
./setup-cluster.sh cleanup
```

### Manual Cleanup
```bash
# Destroy Terraform resources
cd terraform
terraform destroy -auto-approve

# Delete kind cluster
kind delete cluster --name kube-agent-demo

# Clean up port forwards
pkill -f "kubectl port-forward"
```

## Next Steps

1. **Explore Grafana Dashboards**: Import or create dashboards for kube-agent metrics
2. **Customize Alerts**: Modify the PrometheusRules in `terraform/alert-simulation.tf`
3. **Extend kube-agent**: Add more sophisticated alert processing logic
4. **Production Setup**: Deploy to a real Kubernetes cluster using the Helm chart

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     kind Cluster                             │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   Control    │  │   Worker 1   │  │   Worker 2      │   │
│  │   Plane      │  │              │  │                 │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              monitoring namespace                      │ │
│  │  ┌───────────┐ ┌─────────────┐ ┌──────────────────┐   │ │
│  │  │Prometheus │ │Alertmanager │ │    Grafana       │   │ │
│  │  │           │ │             │ │                  │   │ │
│  │  │  :9090    │ │    :9093    │ │     :3000        │   │ │
│  │  └───────────┘ └─────────────┘ └──────────────────┘   │ │
│  └─────────────────────────────────────────────────────────┘ │
│                               │                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                default namespace                       │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │              kube-agent                          │  │ │
│  │  │           FastAPI :8000                          │  │ │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐    │  │ │
│  │  │  │/health  │ │/metrics │ │/alerts (webhook)│    │  │ │
│  │  │  └─────────┘ └─────────┘ └─────────────────┘    │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │             test-workloads namespace                   │ │
│  │  ┌─────────────┐ ┌──────────────────────────────────┐  │ │
│  │  │failing-app  │ │       high-memory-app            │  │ │
│  │  │(crashes)    │ │    (consumes memory)             │  │ │
│  │  └─────────────┘ └──────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │   Host Machine      │
                    │  Port Forwards:     │
                    │  :3000 → Grafana    │
                    │  :8080 → kube-agent │
                    │  :9090 → Prometheus │
                    │  :9093 → Alertmgr   │
                    └─────────────────────┘
```