# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

# Deploy kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "57.0.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
      
      # Alertmanager configuration with webhook to kube-agent
      alertmanager = {
        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            group_by        = ["alertname"]
            group_wait      = "5s"
            group_interval  = "5s"
            repeat_interval = "12h"
            receiver        = "kube-agent"
          }
          receivers = [
            {
              name = "kube-agent"
              webhook_configs = [
                {
                  url = "http://kube-agent.default.svc.cluster.local:8000/alerts"
                  send_resolved = true
                  title = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
                  text = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                }
              ]
            }
          ]
        }
      }
      
      # Grafana configuration
      grafana = {
        adminPassword = "admin"
        service = {
          type = "NodePort"
          nodePort = 30000
        }
      }
      
      # Node exporter
      nodeExporter = {
        enabled = true
      }
      
      # Kube state metrics
      kubeStateMetrics = {
        enabled = true
      }
    })
  ]

  timeout = 600
  
  depends_on = [kubernetes_namespace.monitoring]
}

# Deploy NGINX Ingress Controller (optional)
resource "helm_release" "nginx_ingress" {
  count = var.enable_ingress ? 1 : 0
  
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.0"
  namespace  = "ingress-nginx"
  
  create_namespace = true
  
  values = [
    yamlencode({
      controller = {
        service = {
          type = "NodePort"
          nodePorts = {
            http  = 30001
            https = 30002
          }
        }
        hostNetwork = false
        nodeSelector = {
          "ingress-ready" = "true"
        }
        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "Equal"
            effect   = "NoSchedule"
          },
          {
            key      = "node-role.kubernetes.io/master"
            operator = "Equal"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
  
  timeout = 300
}