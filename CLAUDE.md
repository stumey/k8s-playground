# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A local Kubernetes playground environment built on Kind for experimenting with operators, controllers, service meshes, and cloud-native technologies. The cluster runs on Kubernetes v1.31.12 with a multi-node setup (1 control-plane + 2 workers).

## Common Commands

### Cluster Lifecycle
```bash
make setup              # Create Kind cluster + install Traefik + metrics-server
make teardown           # Delete the Kind cluster
make status             # Check cluster and pod status across all namespaces
make cluster-info       # Display cluster info and nodes
make validate           # Validate cluster health
```

### Application Deployment
```bash
make deploy-sample      # Deploy sample nginx app via kubectl apply
make delete-sample      # Remove sample app
make port-forward       # Port-forward sample app to localhost:8080
```

### Infrastructure Tools
```bash
make install-traefik    # Install Traefik (auto-installed during setup)
make install-headlamp   # Install Headlamp Kubernetes UI
make install-istio      # Install Istio service mesh
make install-prometheus # Install Prometheus monitoring
make headlamp-token     # Generate authentication token for Headlamp
```

### Development Utilities
```bash
make logs               # Tail logs from all pods in default namespace
make shell POD=<name>   # Open shell in specific pod
make watch              # Watch all resources across cluster
make k9s                # Launch k9s terminal UI
```

## Architecture

### Cluster Configuration

**Multi-node Kind cluster** (`clusters/kind/cluster-config.yaml`):
- 1 control-plane node with port mappings for HTTP (80), HTTPS (443), and metrics (10250)
- 2 worker nodes for distributed workloads
- Pod subnet: 10.244.0.0/16
- Service subnet: 10.96.0.0/12
- Control-plane labeled with `ingress-ready=true` for Traefik placement

### Ingress Architecture

**Traefik** is the default ingress controller, configured specifically for Kind:
- Runs on control-plane node (uses nodeSelector `ingress-ready: true`)
- NodePort service type with hostPort bindings (80, 443)
- Tolerations to run on control-plane despite taints
- Single replica for local development
- Configuration: `infrastructure/traefik/values.yaml`

### Directory Structure

```
├── apps/                    # Application deployments
│   └── sample-app/
│       ├── k8s/manifests/  # Raw Kubernetes YAML (used by make deploy-sample)
│       └── helm/           # Helm chart alternative
├── clusters/kind/          # Kind cluster configuration
├── infrastructure/         # Infrastructure tool configs
│   ├── traefik/           # Ingress controller (Helm values)
│   ├── headlamp/          # Kubernetes UI (Helm values + ingress)
│   ├── istio/             # Service mesh configs
│   ├── prometheus/        # Monitoring configs
│   └── monitoring/        # General monitoring stack
└── scripts/               # Automation scripts
    ├── install-tools.sh   # Install kubectl, kind, helm, k9s
    ├── setup-cluster.sh   # Create cluster + setup infrastructure
    └── teardown-cluster.sh
```

### Setup Flow

When running `make setup`, the following happens (`scripts/setup-cluster.sh:138-156`):
1. Check dependencies (kind, kubectl, docker)
2. Verify Docker daemon is running
3. Create Kind cluster from config
4. Wait for nodes to be Ready
5. Install metrics-server (patched with `--kubelet-insecure-tls` for Kind)
6. Install Traefik via Helm
7. Wait for Traefik pods to be ready

### Sample Application

The sample app demonstrates two deployment approaches:
- **Manifest-based**: `apps/sample-app/k8s/manifests/` - used by `make deploy-sample`
- **Helm-based**: `apps/sample-app/helm/` - alternative deployment method

Uses nginx:1.27-alpine with:
- 2 replicas
- Resource limits: 200m CPU, 128Mi memory
- Liveness and readiness probes on HTTP /
- ClusterIP service on port 80

### Headlamp UI Setup

Headlamp requires manual /etc/hosts configuration:
```bash
make install-headlamp
echo "127.0.0.1 headlamp.local" | sudo tee -a /etc/hosts
make headlamp-token  # Generates and copies token to clipboard
```

Access at http://headlamp.local and paste the token for authentication.

## Key Implementation Details

### Traefik on Kind

Traefik must run on the control-plane node because:
- Kind only maps ports (80, 443) to the control-plane container
- Uses `nodeSelector: ingress-ready: "true"` to target control-plane
- Requires tolerations for control-plane taints

### Metrics Server

Metrics-server is patched post-installation with `--kubelet-insecure-tls` because Kind uses self-signed certificates. Without this, `kubectl top` commands fail.

### Cluster Name

All scripts reference cluster name "playground" - changing this requires updates to:
- `Makefile:7` (CLUSTER_NAME variable)
- `scripts/setup-cluster.sh:12`
- `clusters/kind/cluster-config.yaml:3`
