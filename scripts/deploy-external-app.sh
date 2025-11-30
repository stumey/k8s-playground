#!/usr/bin/env bash

# Deploy an external application to the k8s-playground cluster
# Detects configuration, builds image, loads into Kind, and deploys
#
# Usage: ./deploy-external-app.sh <app-path> [app-name] [options]
#
# Options:
#   --port=<port>        Container port (auto-detected if possible)
#   --build-only         Only build and load image, don't deploy
#   --deploy-only        Only deploy (assumes image already loaded)
#   --cleanup            Remove the deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-playground}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 <app-path> [app-name] [options]

Arguments:
  app-path             Path to your application directory
  app-name             Optional name for the app (defaults to directory name)

Options:
  --port=<port>        Container port (auto-detected if possible)
  --build-only         Only build and load image, don't deploy
  --deploy-only        Only deploy (assumes image already loaded)
  --cleanup            Remove the deployment

Examples:
  $0 ~/projects/my-api                           # Deploy with auto-detection
  $0 ~/projects/my-api myapi --port=3000         # Specify name and port
  $0 ~/projects/my-api --build-only              # Just build and load image
  $0 ~/projects/my-api --cleanup                 # Remove deployment

Detection:
  - Auto-detects Dockerfile, skaffold.yaml, Helm charts, k8s manifests
  - If none found, generates minimal deployment
  - Infers app name from directory if not specified
EOF
}

# Parse arguments
parse_args() {
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi

    APP_PATH="$1"
    shift

    # Check if second arg is a name or option
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        APP_NAME="$1"
        shift
    else
        APP_NAME=""
    fi

    # Defaults
    CONTAINER_PORT=""
    BUILD_ONLY=false
    DEPLOY_ONLY=false
    CLEANUP=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --port=*)
                CONTAINER_PORT="${1#*=}"
                ;;
            --build-only)
                BUILD_ONLY=true
                ;;
            --deploy-only)
                DEPLOY_ONLY=true
                ;;
            --cleanup)
                CLEANUP=true
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

validate_app_path() {
    if [[ ! -d "$APP_PATH" ]]; then
        log_error "App directory not found: $APP_PATH"
        exit 1
    fi

    APP_PATH="$(cd "$APP_PATH" && pwd)"  # Get absolute path

    if [[ -z "$APP_NAME" ]]; then
        APP_NAME="$(basename "$APP_PATH")"
        log_info "Using app name: $APP_NAME"
    fi

    # Validate app name
    if [[ ! "$APP_NAME" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        log_warn "App name contains invalid characters, normalizing..."
        APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/[^a-z0-9-]//g')
        log_info "Normalized name: $APP_NAME"
    fi
}

check_cluster() {
    if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_error "Kind cluster '${CLUSTER_NAME}' not found"
        log_info "Run 'make setup' to create the cluster"
        exit 1
    fi
}

detect_configuration() {
    log_step "Detecting application configuration..."

    # Check for Skaffold
    if [[ -f "$APP_PATH/skaffold.yaml" ]]; then
        HAS_SKAFFOLD=true
        log_info "✓ Found skaffold.yaml"
    else
        HAS_SKAFFOLD=false
    fi

    # Check for Dockerfile
    if [[ -f "$APP_PATH/Dockerfile" ]]; then
        HAS_DOCKERFILE=true
        log_info "✓ Found Dockerfile"
    else
        HAS_DOCKERFILE=false
        log_warn "No Dockerfile found"
    fi

    # Check for Helm chart
    if [[ -f "$APP_PATH/helm/Chart.yaml" ]] || [[ -f "$APP_PATH/chart/Chart.yaml" ]]; then
        HAS_HELM=true
        if [[ -f "$APP_PATH/helm/Chart.yaml" ]]; then
            HELM_CHART_PATH="$APP_PATH/helm"
        else
            HELM_CHART_PATH="$APP_PATH/chart"
        fi
        log_info "✓ Found Helm chart at: $HELM_CHART_PATH"
    else
        HAS_HELM=false
    fi

    # Check for k8s manifests
    if [[ -d "$APP_PATH/k8s" ]] || [[ -d "$APP_PATH/manifests" ]]; then
        HAS_MANIFESTS=true
        if [[ -d "$APP_PATH/k8s" ]]; then
            MANIFESTS_PATH="$APP_PATH/k8s"
        else
            MANIFESTS_PATH="$APP_PATH/manifests"
        fi
        log_info "✓ Found manifests at: $MANIFESTS_PATH"
    else
        HAS_MANIFESTS=false
    fi

    # Auto-detect port if not specified
    if [[ -z "$CONTAINER_PORT" ]]; then
        detect_port
    fi
}

detect_port() {
    local port=""

    # Try to detect from Dockerfile
    if [[ -f "$APP_PATH/Dockerfile" ]]; then
        port=$(grep -m1 "^EXPOSE" "$APP_PATH/Dockerfile" | awk '{print $2}' || true)
    fi

    # Try common config files if Dockerfile didn't have EXPOSE
    if [[ -z "$port" ]]; then
        # Node.js package.json scripts
        if [[ -f "$APP_PATH/package.json" ]]; then
            port=$(grep -o "PORT.*[0-9]\+" "$APP_PATH/package.json" | grep -o "[0-9]\+" | head -1 || true)
        fi

        # .NET launchSettings.json
        if [[ -z "$port" ]] && [[ -f "$APP_PATH/Properties/launchSettings.json" ]]; then
            port=$(grep -o "applicationUrl.*http://.*:[0-9]\+" "$APP_PATH/Properties/launchSettings.json" | grep -o "[0-9]\+" | head -1 || true)
        fi
    fi

    if [[ -n "$port" ]]; then
        CONTAINER_PORT="$port"
        log_info "Auto-detected port: $CONTAINER_PORT"
    else
        CONTAINER_PORT="8080"
        log_warn "Could not detect port, using default: $CONTAINER_PORT"
    fi
}

build_and_load_image() {
    if [[ "$DEPLOY_ONLY" == true ]]; then
        log_info "Skipping build (--deploy-only)"
        return
    fi

    if [[ "$HAS_DOCKERFILE" == false ]]; then
        log_error "Cannot build: No Dockerfile found"
        log_info "Add a Dockerfile or use templates from: $REPO_ROOT/scripts/templates/app-samples/"
        exit 1
    fi

    log_step "Building Docker image: $APP_NAME:dev"

    cd "$APP_PATH"
    if docker build -t "$APP_NAME:dev" .; then
        log_info "✓ Build successful"
    else
        log_error "Build failed"
        exit 1
    fi

    log_step "Loading image into Kind cluster"
    if kind load docker-image "$APP_NAME:dev" --name "$CLUSTER_NAME"; then
        log_info "✓ Image loaded into cluster"
    else
        log_error "Failed to load image"
        exit 1
    fi
}

deploy_with_skaffold() {
    log_step "Deploying with Skaffold"

    cd "$APP_PATH"

    # Check if skaffold is installed
    if ! command -v skaffold &> /dev/null; then
        log_error "Skaffold not found. Install it with: scripts/install-tools.sh"
        exit 1
    fi

    log_info "Running: skaffold run"
    skaffold run

    log_info "✓ Deployed with Skaffold"
}

deploy_with_helm() {
    log_step "Deploying with Helm"

    # Check for values-local.yaml, otherwise use values.yaml
    local values_file=""
    if [[ -f "$HELM_CHART_PATH/values-local.yaml" ]]; then
        values_file="-f $HELM_CHART_PATH/values-local.yaml"
        log_info "Using values-local.yaml"
    elif [[ -f "$HELM_CHART_PATH/values.yaml" ]]; then
        values_file="-f $HELM_CHART_PATH/values.yaml"
        log_info "Using values.yaml"
    fi

    # Install or upgrade
    if helm status "$APP_NAME" &>/dev/null; then
        log_info "Upgrading existing release"
        helm upgrade "$APP_NAME" "$HELM_CHART_PATH" \
            $values_file \
            --set image.repository="$APP_NAME" \
            --set image.tag="dev" \
            --set image.pullPolicy="IfNotPresent"
    else
        log_info "Installing new release"
        helm install "$APP_NAME" "$HELM_CHART_PATH" \
            $values_file \
            --set image.repository="$APP_NAME" \
            --set image.tag="dev" \
            --set image.pullPolicy="IfNotPresent"
    fi

    log_info "✓ Deployed with Helm"
}

deploy_with_manifests() {
    log_step "Deploying with kubectl manifests"

    kubectl apply -f "$MANIFESTS_PATH"

    log_info "✓ Applied manifests"
}

deploy_minimal() {
    log_step "Generating minimal deployment"

    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Create minimal deployment
    cat > "$temp_dir/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $APP_NAME:dev
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: $CONTAINER_PORT
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: $CONTAINER_PORT
    protocol: TCP
    name: http
  selector:
    app: $APP_NAME
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  ingressClassName: traefik
  rules:
  - host: $APP_NAME.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $APP_NAME
            port:
              number: 80
EOF

    log_info "Generated minimal k8s manifests"
    kubectl apply -f "$temp_dir/deployment.yaml"

    log_info "✓ Deployed with generated manifests"
    log_warn "Add to /etc/hosts: 127.0.0.1 $APP_NAME.local"
}

deploy_app() {
    if [[ "$BUILD_ONLY" == true ]]; then
        log_info "Skipping deployment (--build-only)"
        return
    fi

    log_step "Deploying application: $APP_NAME"

    # Priority: Skaffold > Helm > Manifests > Generate minimal
    if [[ "$HAS_SKAFFOLD" == true ]]; then
        deploy_with_skaffold
    elif [[ "$HAS_HELM" == true ]]; then
        deploy_with_helm
    elif [[ "$HAS_MANIFESTS" == true ]]; then
        deploy_with_manifests
    else
        deploy_minimal
    fi
}

cleanup_app() {
    log_step "Cleaning up deployment: $APP_NAME"

    # Try Skaffold first
    if [[ "$HAS_SKAFFOLD" == true ]] && [[ -f "$APP_PATH/skaffold.yaml" ]]; then
        cd "$APP_PATH"
        skaffold delete || true
    fi

    # Try Helm
    if helm status "$APP_NAME" &>/dev/null; then
        helm uninstall "$APP_NAME"
        log_info "✓ Helm release uninstalled"
    fi

    # Try kubectl
    kubectl delete deployment "$APP_NAME" 2>/dev/null || true
    kubectl delete service "$APP_NAME" 2>/dev/null || true
    kubectl delete ingress "$APP_NAME" 2>/dev/null || true

    log_info "✓ Cleanup complete"
}

show_access_info() {
    log_info ""
    log_info "================================================================"
    log_info "DEPLOYMENT SUCCESSFUL: $APP_NAME"
    log_info "================================================================"
    log_info ""
    log_info "Access your app:"
    log_info "  - Add to /etc/hosts: 127.0.0.1 $APP_NAME.local"
    log_info "  - URL: http://$APP_NAME.local"
    log_info "  - Port-forward: kubectl port-forward svc/$APP_NAME $CONTAINER_PORT:80"
    log_info ""
    log_info "Useful commands:"
    log_info "  - Logs: kubectl logs -l app=$APP_NAME -f"
    log_info "  - Status: kubectl get pods -l app=$APP_NAME"
    log_info "  - Cleanup: $0 $APP_PATH --cleanup"
    log_info ""
    log_info "================================================================"
}

main() {
    parse_args "$@"
    validate_app_path
    check_cluster

    if [[ "$CLEANUP" == true ]]; then
        detect_configuration
        cleanup_app
        exit 0
    fi

    log_info "Deploying: $APP_PATH"
    log_info "App name: $APP_NAME"
    echo

    detect_configuration
    build_and_load_image
    deploy_app

    echo
    show_access_info
}

main "$@"
