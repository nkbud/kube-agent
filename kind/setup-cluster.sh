#!/bin/bash
set -euo pipefail

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"kube-agent-demo"}
NODE_IMAGE=${NODE_IMAGE:-"kindest/node:v1.29.0"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kind &> /dev/null; then
        error "kind is not installed. Please install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed. Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed. Please install helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        error "terraform is not installed. Please install terraform: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "docker is not installed. Please install docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    log "All prerequisites are installed!"
}

# Create kind cluster
create_cluster() {
    log "Creating kind cluster: $CLUSTER_NAME"
    
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        warn "Cluster $CLUSTER_NAME already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    # Create cluster with configuration
    kind create cluster --name "$CLUSTER_NAME" --image "$NODE_IMAGE" --config "$SCRIPT_DIR/kind-config.yaml"
    
    log "Cluster $CLUSTER_NAME created successfully!"
    
    # Wait for cluster to be ready
    log "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log "Cluster is ready!"
}

# Load Docker image into kind cluster
load_image() {
    local image="$1"
    log "Loading Docker image into kind cluster: $image"
    
    if docker image inspect "$image" &> /dev/null; then
        kind load docker-image "$image" --name "$CLUSTER_NAME"
        log "Image $image loaded successfully!"
    else
        warn "Image $image not found locally. Skipping..."
    fi
}

# Deploy with Terraform
deploy_with_terraform() {
    log "Deploying applications with Terraform..."
    
    cd "$SCRIPT_DIR/terraform"
    
    # Initialize Terraform
    terraform init
    
    # Plan and apply
    terraform plan -var="cluster_name=$CLUSTER_NAME"
    terraform apply -auto-approve -var="cluster_name=$CLUSTER_NAME"
    
    log "Terraform deployment completed!"
}

# Show cluster info
show_cluster_info() {
    log "Cluster Information:"
    echo "===================="
    
    echo
    echo "Cluster Status:"
    kubectl cluster-info
    
    echo
    echo "Nodes:"
    kubectl get nodes -o wide
    
    echo
    echo "Namespaces:"
    kubectl get namespaces
    
    echo
    echo "Pods in kube-system:"
    kubectl get pods -n kube-system
    
    echo
    echo "Pods in monitoring:"
    kubectl get pods -n monitoring 2>/dev/null || echo "Monitoring namespace not found"
    
    echo
    echo "Pods in default:"
    kubectl get pods -n default
    
    echo
    echo "Services:"
    kubectl get services --all-namespaces
    
    echo
    log "Setup completed! You can access your cluster with: kubectl --context kind-$CLUSTER_NAME"
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    if [ -d "$SCRIPT_DIR/terraform" ]; then
        cd "$SCRIPT_DIR/terraform"
        terraform destroy -auto-approve -var="cluster_name=$CLUSTER_NAME" || warn "Terraform destroy failed"
    fi
    
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        kind delete cluster --name "$CLUSTER_NAME"
        log "Cluster $CLUSTER_NAME deleted!"
    fi
}

# Main function
main() {
    case "${1:-setup}" in
        setup)
            check_prerequisites
            create_cluster
            deploy_with_terraform
            show_cluster_info
            ;;
        cleanup|destroy)
            cleanup
            ;;
        info)
            show_cluster_info
            ;;
        *)
            echo "Usage: $0 {setup|cleanup|destroy|info}"
            echo "  setup    - Create kind cluster and deploy applications"
            echo "  cleanup  - Destroy cluster and clean up resources"
            echo "  destroy  - Alias for cleanup"
            echo "  info     - Show cluster information"
            exit 1
            ;;
    esac
}

# Handle interruption
trap cleanup INT TERM

main "$@"