# Kubernetes Playground

A local Kubernetes environment for experimenting with operators, controllers, service meshes, and cloud-native technologies.

## Prerequisites

- Docker
- kubectl
- Kind
- Helm (optional)

## Quick Start

Install tools:
```bash
make install-tools
```

Create cluster:
```bash
make setup
```

Verify:
```bash
make cluster-info
```

Deploy sample app:
```bash
make deploy-sample
kubectl port-forward svc/sample-app 8080:80
```

## Structure

```
├── apps/              # Application deployments
├── clusters/kind/     # Kind cluster configuration
├── infrastructure/    # Traefik, Istio, Prometheus, Headlamp configs
├── scripts/           # Automation scripts
└── Makefile          # Common operations
```

## Common Commands

```bash
make setup              # Create cluster with Traefik ingress
make teardown           # Delete cluster
make status             # Check cluster status
make deploy-sample      # Deploy sample application
make install-traefik    # Install Traefik ingress (auto-installed during setup)
make install-istio      # Install Istio
make install-prometheus # Install Prometheus
make install-headlamp   # Install Headlamp UI
make headlamp           # Open Headlamp in browser
```

## Headlamp UI

Access your cluster through a modern web interface:

```bash
# Install Headlamp
make install-headlamp

# Add to /etc/hosts
echo "127.0.0.1 headlamp.local" | sudo tee -a /etc/hosts

# Open in browser
make headlamp
# Or visit: http://headlamp.local
```

Headlamp provides:
- Visual resource explorer
- Real-time cluster monitoring
- YAML editor
- Pod logs and shell access
- Resource metrics and graphs

## Cleanup

```bash
make teardown
```
