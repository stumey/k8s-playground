#!/usr/bin/env bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly CLUSTER_NAME="playground"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_kind() {
    if ! command -v kind &> /dev/null; then
        log_error "kind is not installed."
        exit 1
    fi
}

delete_cluster() {
    log_info "Checking if cluster '${CLUSTER_NAME}' exists..."

    if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '${CLUSTER_NAME}' does not exist."
        exit 0
    fi

    log_warn "This will delete the cluster '${CLUSTER_NAME}' and all resources in it."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted."
        exit 0
    fi

    log_info "Deleting cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"

    log_info "✓ Cluster deleted successfully!"
}

main() {
    check_kind
    delete_cluster
}

main "$@"
