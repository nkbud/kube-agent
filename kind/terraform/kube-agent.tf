# Deploy kube-agent using local Helm chart
resource "helm_release" "kube_agent" {
  name  = "kube-agent"
  chart = "../../helm/kube-agent"
  
  namespace        = "default"
  create_namespace = false
  
  values = [
    yamlencode({
      image = {
        repository = var.kube_agent_image
        tag        = "latest"
        pullPolicy = "IfNotPresent"
      }
      
      # Enable service monitor for Prometheus scraping
      serviceMonitor = {
        enabled = true
        labels = {
          release = "kube-prometheus-stack"
        }
      }
      
      # Resource limits for demo
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      
      # Environment variables
      env = {
        KUBE_AGENT_LOG_LEVEL = "DEBUG"
        KUBE_AGENT_IN_CLUSTER = "true"
      }
    })
  ]
  
  timeout = 300
  
  # Wait for monitoring to be deployed first
  depends_on = [helm_release.kube_prometheus_stack]
}