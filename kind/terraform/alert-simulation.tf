# Alert simulation charts - Deploy workloads that will trigger alerts

# Create a namespace for test workloads
resource "kubernetes_namespace" "test_workloads" {
  metadata {
    name = "test-workloads"
    labels = {
      name = "test-workloads"
    }
  }
}

# Deploy a deployment that will fail (to trigger alerts)
resource "kubernetes_deployment" "failing_app" {
  metadata {
    name      = "failing-app"
    namespace = kubernetes_namespace.test_workloads.metadata[0].name
    labels = {
      app = "failing-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "failing-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "failing-app"
        }
      }

      spec {
        container {
          image = "alpine:latest"
          name  = "failing-container"
          
          # This command will fail after 30 seconds
          command = ["/bin/sh", "-c", "sleep 30 && exit 1"]
          
          resources {
            limits = {
              cpu    = "10m"
              memory = "16Mi"
            }
            requests = {
              cpu    = "5m"
              memory = "8Mi"
            }
          }
        }
        
        restart_policy = "Always"
      }
    }
  }
}

# Deploy a deployment with resource constraints (to trigger resource alerts)
resource "kubernetes_deployment" "high_memory_app" {
  metadata {
    name      = "high-memory-app"
    namespace = kubernetes_namespace.test_workloads.metadata[0].name
    labels = {
      app = "high-memory-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "high-memory-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "high-memory-app"
        }
      }

      spec {
        container {
          image = "alpine:latest"
          name  = "memory-consumer"
          
          # This will consume memory gradually
          command = ["/bin/sh", "-c", "while true; do dd if=/dev/zero of=/dev/null bs=1M count=10; sleep 5; done"]
          
          resources {
            limits = {
              cpu    = "50m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
          }
        }
      }
    }
  }
}

# Create a PrometheusRule for custom alerts
resource "kubernetes_manifest" "custom_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "kube-agent-demo-alerts"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        prometheus = "kube-prometheus-stack-prometheus"
        role       = "alert-rules"
      }
    }
    spec = {
      groups = [
        {
          name = "kube-agent.demo"
          rules = [
            {
              alert = "PodCrashLooping"
              expr  = "rate(kube_pod_container_status_restarts_total[5m]) > 0"
              for   = "1m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been restarting frequently"
              }
            },
            {
              alert = "HighMemoryUsage"
              expr  = "(container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.8"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "High memory usage detected"
                description = "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} is using more than 80% of its memory limit"
              }
            },
            {
              alert = "KubeAgentDown"
              expr  = "up{job=\"kube-agent\"} == 0"
              for   = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Kube Agent is down"
                description = "Kube Agent has been down for more than 1 minute"
              }
            }
          ]
        }
      ]
    }
  }
  
  depends_on = [helm_release.kube_prometheus_stack]
}