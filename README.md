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
├── infrastructure/    # Istio, Prometheus, monitoring configs
├── scripts/           # Automation scripts
└── Makefile          # Common operations
```

## Common Commands

```bash
make setup              # Create cluster
make teardown           # Delete cluster
make status             # Check cluster status
make deploy-sample      # Deploy sample application
make install-istio      # Install Istio
make install-prometheus # Install Prometheus
```

## Cleanup

```bash
make teardown
```
