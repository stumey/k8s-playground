# Infrastructure Tools

This directory contains configurations and setup scripts for various Kubernetes infrastructure tools and addons.

## Available Tools

### Ingress Controller

- **Traefik**: Modern, cloud-native ingress controller and reverse proxy (auto-installed during cluster setup)

### UI & Dashboard

- **Headlamp**: Modern, extensible Kubernetes web UI for cluster management and exploration

### Monitoring

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Metrics visualization and dashboards
- **Alertmanager**: Alert routing and management

### Service Mesh

- **Istio**: Service mesh for microservices communication, security, and observability

### Other Tools

Additional tools can be added here such as:
- ArgoCD for GitOps
- cert-manager for TLS certificates
- External Secrets Operator
- Custom Operators and Controllers

## Installation

### Quick Start

Each tool has its own directory with installation instructions. Generally, you can install tools using:

```bash
# Using Make
make install-traefik      # Ingress controller (auto-installed)
make install-headlamp     # Kubernetes web UI
make install-prometheus   # Monitoring stack
make install-istio        # Service mesh
```

### Traefik

Traefik is automatically installed during cluster setup. To manually install:

```bash
make install-traefik
```

See `infrastructure/traefik/README.md` for detailed documentation.

### Headlamp

To install and access Headlamp:

```bash
# Install Headlamp
make install-headlamp

# Add to /etc/hosts
echo "127.0.0.1 headlamp.local" | sudo tee -a /etc/hosts

# Access at http://headlamp.local
make headlamp
```

See `infrastructure/headlamp/README.md` for detailed documentation.

### Istio

To install Istio:

```bash
# Download istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set profile=demo -y

# Enable sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled
```

### Prometheus & Grafana

To install Prometheus using Helm:

```bash
# Add Prometheus helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Grafana)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default credentials: admin / prom-operator
```

## Directory Structure

```
infrastructure/
├── README.md
├── traefik/            # Traefik ingress controller
├── headlamp/           # Headlamp Kubernetes UI
├── istio/              # Istio service mesh configs
├── prometheus/         # Prometheus monitoring configs
└── monitoring/         # General monitoring stack
```

## Best Practices

1. **Namespace Isolation**: Deploy infrastructure tools in dedicated namespaces
2. **Resource Limits**: Always set resource requests and limits
3. **RBAC**: Use Role-Based Access Control for security
4. **Secrets Management**: Never commit secrets to git
5. **High Availability**: Use multiple replicas for critical components

## Testing Tools

After installation, verify the tools are running:

```bash
# Check all pods in monitoring namespace
kubectl get pods -n monitoring

# Check Istio components
kubectl get pods -n istio-system

# Check metrics
kubectl top nodes
kubectl top pods
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod to see events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>
```

### Resource Issues

```bash
# Check node resources
kubectl describe nodes

# Check resource quotas
kubectl get resourcequotas --all-namespaces
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
