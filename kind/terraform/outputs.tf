output "cluster_info" {
  description = "Information about the deployed cluster"
  value = {
    cluster_name = var.cluster_name
    context      = "kind-${var.cluster_name}"
  }
}

output "access_info" {
  description = "Access information for services"
  value = {
    grafana = {
      url      = "http://localhost:30000"
      username = "admin"
      password = "admin"
    }
    ingress_http  = var.enable_ingress ? "http://localhost:30001" : "Not enabled"
    ingress_https = var.enable_ingress ? "https://localhost:30002" : "Not enabled"
    kube_agent = {
      service = "kube-agent.default.svc.cluster.local:8000"
      health  = "kubectl port-forward svc/kube-agent 8080:8000 & curl http://localhost:8080/health"
    }
  }
}

output "useful_commands" {
  description = "Useful commands for interacting with the cluster"
  value = {
    kubectl_context    = "kubectl config use-context kind-${var.cluster_name}"
    port_forward_grafana = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    port_forward_kube_agent = "kubectl port-forward svc/kube-agent 8080:8000"
    view_alerts = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
    view_prometheus = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    check_kube_agent_logs = "kubectl logs -l app.kubernetes.io/name=kube-agent -f"
    trigger_test_alert = "kubectl delete pod -l app=failing-app -n test-workloads"
  }
}