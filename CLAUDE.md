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
make deploy-sample                          # Deploy sample nginx app via kubectl apply
make delete-sample                          # Remove sample app
make port-forward                           # Port-forward sample app to localhost:8080

# Deploy external apps (from separate repos)
make deploy-external APP_PATH=~/my-app     # Deploy external app with auto-detection
make build-external APP_PATH=~/my-app      # Build and load image only
make cleanup-external APP_PATH=~/my-app    # Remove external app deployment
./scripts/deploy-external-app.sh ~/my-app  # Direct script usage
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
├── apps/                         # Application deployments
│   └── sample-app/
│       ├── k8s/manifests/       # Raw Kubernetes YAML (used by make deploy-sample)
│       └── helm/                # Helm chart alternative
├── clusters/kind/               # Kind cluster configuration
├── infrastructure/              # Infrastructure tool configs
│   ├── traefik/                # Ingress controller (Helm values)
│   ├── headlamp/               # Kubernetes UI (Helm values + ingress)
│   ├── istio/                  # Service mesh configs
│   ├── prometheus/             # Monitoring configs
│   └── monitoring/             # General monitoring stack
└── scripts/                     # Automation scripts
    ├── install-tools.sh        # Install kubectl, kind, helm, k9s, skaffold
    ├── setup-cluster.sh        # Create cluster + setup infrastructure
    ├── teardown-cluster.sh     # Delete cluster
    ├── deploy-external-app.sh  # Deploy apps from external repos
    └── templates/              # Templates for external projects
        ├── drop-in/            # Ready-to-copy Skaffold/Helm configs
        ├── helm/               # Reusable Helm chart templates
        └── starters/           # Complete starter projects (Node.js, .NET, Go)
```

### Setup Flow

When running `make setup`, the following happens (`scripts/setup-cluster.sh:149-159`):
1. Check dependencies (kind, kubectl, docker)
2. Verify Docker daemon is running
3. Create Kind cluster from config
4. Wait for nodes to be Ready
5. Install metrics-server (patched with `--kubelet-insecure-tls` for Kind)
6. Install Traefik via Helm
7. Wait for Traefik pods to be ready
8. Configure local storage provisioner (for PVCs)

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

## Onboarding External Applications

This playground is designed to make it easy to test applications developed in **separate repositories** before deploying to the cloud. You can onboard any external app with minimal configuration.

### Quick Deploy (Zero Configuration)

The fastest way to deploy an external app:

```bash
# From the k8s-playground repo
./scripts/deploy-external-app.sh ~/path/to/your-app

# Or use Make
make deploy-external APP_PATH=~/path/to/your-app
```

**What it does:**
- Auto-detects Dockerfile, Skaffold, Helm charts, or k8s manifests
- Builds and loads image into Kind cluster
- Deploys using detected configuration or generates minimal resources
- Sets up ingress at `<app-name>.local`

**Requirements:**
- Your app must have a `Dockerfile`
- That's it!

### Deployment Methods

The deploy script supports multiple deployment approaches (in priority order):

1. **Skaffold** (`skaffold.yaml` in app root)
   - Best for continuous development
   - Runs `skaffold run`
   - See drop-in templates: `scripts/templates/drop-in/`

2. **Helm** (`helm/Chart.yaml` or `chart/Chart.yaml`)
   - Deploys with `helm install/upgrade`
   - Auto-uses `values-local.yaml` if present
   - Sets `image.pullPolicy=IfNotPresent` and `image.tag=dev`

3. **Raw Manifests** (`k8s/` or `manifests/` directory)
   - Applies with `kubectl apply -f`

4. **Auto-generated** (no config found)
   - Creates minimal Deployment, Service, and Ingress
   - Uses port auto-detection or defaults to 8080

### Common Workflows

#### Development with Skaffold (Recommended)

Add Skaffold to your external app for the best dev experience:

```bash
# Copy drop-in template
cp scripts/templates/drop-in/skaffold-helm.yaml ~/your-app/skaffold.yaml

# Edit to customize app name, ports, sync patterns
vim ~/your-app/skaffold.yaml

# Start continuous development
cd ~/your-app
skaffold dev --profile=debug  # Hot reload enabled
```

File changes sync automatically without rebuilding!

#### One-Time Deployment

```bash
# Deploy once
make deploy-external APP_PATH=~/your-app

# Access at:
# http://your-app.local (add to /etc/hosts first)
```

#### Build-Only (No Deploy)

```bash
# Just build and load image into Kind
make build-external APP_PATH=~/your-app

# Then deploy manually
kubectl apply -f ~/your-app/k8s/
```

#### Cleanup

```bash
make cleanup-external APP_PATH=~/your-app

# Or if using Skaffold
cd ~/your-app && skaffold delete
```

### Drop-in Templates

Located in `scripts/templates/drop-in/`, ready to copy to external projects:

- **skaffold-helm.yaml** - For Helm-based apps
- **skaffold-manifests.yaml** - For raw manifest apps
- **helm/** - Minimal Helm chart template

See `scripts/templates/drop-in/README.md` for detailed usage.

### Language Starter Templates

Located in `scripts/templates/starters/`, these are complete starter projects you can copy:

- **nodejs/** - Node.js HTTP server with health checks
- **dotnet/** - .NET 8 Minimal API with ASP.NET Core
- **go/** - Go 1.22 with net/http

Each includes:
- Multi-stage Dockerfile
- Sample application code
- .dockerignore
- All ready to deploy

Usage:
```bash
cp -r scripts/templates/starters/nodejs ~/my-new-app
cd ~/my-new-app
# Customize your app
# Then deploy:
make deploy-external APP_PATH=~/my-new-app
```

### Port Detection

The deploy script auto-detects container ports from:
1. Dockerfile `EXPOSE` directive
2. package.json (Node.js)
3. launchSettings.json (.NET)

Override with `--port=3000` if needed.

### /etc/hosts Configuration

Apps are exposed via Traefik ingress at `<app-name>.local`. Add entries:

```bash
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

### Deployment Script Options

```bash
./scripts/deploy-external-app.sh <app-path> [app-name] [options]

Options:
  --port=<port>     Override container port
  --build-only      Build and load image only, don't deploy
  --deploy-only     Deploy only (assumes image already loaded)
  --cleanup         Remove deployment
```

### Storage for Stateful Apps

Kind includes a local-path storage provisioner by default. PVCs work automatically:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Best Practices

1. **Use values-local.yaml for Kind-specific settings:**
   - Lower resource limits (50m CPU, 64Mi RAM)
   - `imagePullPolicy: IfNotPresent`
   - Single replica
   - Debug logging enabled

2. **Use values.yaml for production settings:**
   - Production resource limits
   - Multiple replicas
   - Autoscaling enabled
   - `imagePullPolicy: Always`

3. **Use Skaffold profiles:**
   - Default profile: standard development
   - `debug` profile: file sync for hot reload
   - `prod` profile: production-like configuration

4. **Keep apps in separate repos:**
   - The playground is just infrastructure
   - Apps live in their own repositories
   - Use the deploy script to test locally before cloud deployment
