#!/usr/bin/env bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly CLUSTER_NAME="playground"
readonly CLUSTER_CONFIG="clusters/kind/cluster-config.yaml"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    if ! command -v kind &> /dev/null; then
        missing_deps+=("kind")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_deps+=("kubectl")
    fi

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again."
        log_info "Visit https://kind.sigs.k8s.io/docs/user/quick-start/ for installation instructions."
        exit 1
    fi

    log_info "All dependencies are installed."
}

check_docker() {
    log_info "Checking Docker daemon..."

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi

    log_info "Docker daemon is running."
}

create_cluster() {
    log_info "Creating Kind cluster '${CLUSTER_NAME}'..."

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '${CLUSTER_NAME}' already exists."
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "${CLUSTER_NAME}"
        else
            log_info "Using existing cluster."
            return 0
        fi
    fi

    cd "${PROJECT_ROOT}"
    kind create cluster --config "${CLUSTER_CONFIG}"

    log_info "Cluster created successfully!"
}

verify_cluster() {
    log_info "Verifying cluster is ready..."

    # Wait for nodes to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    log_info "All nodes are ready."

    # Display cluster info
    log_info "Cluster information:"
    kubectl cluster-info
    echo
    kubectl get nodes -o wide
}

setup_metrics_server() {
    log_info "Installing metrics-server for resource metrics..."

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Patch metrics-server for Kind (insecure TLS)
    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

    log_info "Metrics server installed."
}

setup_ingress_controller() {
    log_info "Installing Traefik ingress controller..."

    # Add Traefik Helm repository
    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update traefik

    # Install Traefik
    helm install traefik traefik/traefik \
        --namespace traefik \
        --create-namespace \
        --values "${PROJECT_ROOT}/infrastructure/traefik/values.yaml"

    log_info "Waiting for Traefik to be ready..."
    kubectl wait --namespace traefik \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=traefik \
        --timeout=90s

    log_info "Traefik ingress controller installed and ready."
}

setup_storage_provisioner() {
    log_step "Setting up local storage provisioner..."

    # Kind includes local-path-provisioner by default, just set it as default
    kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || \
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || \
    log_warn "Could not set default storage class (may already be set)"

    log_info "Local storage provisioner configured."
}

main() {
    log_info "Starting Kind cluster setup..."
    echo

    check_dependencies
    check_docker
    create_cluster
    verify_cluster
    setup_metrics_server
    setup_ingress_controller
    setup_storage_provisioner

    echo
    log_info "✓ Cluster setup complete!"
    log_info "You can now use 'kubectl' to interact with your cluster."
    log_info "Run 'kubectl get nodes' to see your cluster nodes."
    echo
    log_info "To install Headlamp UI, run: make install-headlamp"
}

main "$@"
