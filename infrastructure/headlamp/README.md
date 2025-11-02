# Headlamp - Kubernetes Web UI

Headlamp is an easy-to-use and extensible Kubernetes web UI that provides a visual interface to explore and manage cluster resources.

## Features

- View and manage all Kubernetes resources
- Real-time cluster monitoring
- YAML editor for resources
- Pod logs and shell access
- Resource metrics and graphs
- Multi-cluster support
- Plugin system for extensibility

## Installation

### Using Make (Recommended)

```bash
# Install Headlamp
make install-headlamp

# Access Headlamp UI
# Open http://headlamp.local in your browser
```

### Manual Installation

```bash
# Add Headlamp Helm repository
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update

# Install Headlamp
helm install headlamp headlamp/headlamp \
  --namespace headlamp \
  --create-namespace \
  --values infrastructure/headlamp/values.yaml
```

## Accessing Headlamp

After installation, access Headlamp at: **http://headlamp.local**

### DNS Configuration

Add this entry to your `/etc/hosts` file:

```
127.0.0.1 headlamp.local
```

The ingress configuration will automatically route traffic from your browser to the Headlamp service.

## Uninstallation

```bash
# Using Helm
helm uninstall headlamp -n headlamp

# Delete namespace
kubectl delete namespace headlamp
```

## Configuration

### Ingress

The default configuration uses:
- **Host**: headlamp.local
- **Ingress Controller**: Traefik (auto-discovery)
- **Path**: / (root)

Traefik automatically discovers and handles the ingress - no ingressClassName needed.

To modify the hostname, edit `infrastructure/headlamp/values.yaml` or `infrastructure/headlamp/ingress.yaml`.

### Resources

Default resource limits (suitable for local development):
- CPU: 100m (request) / 200m (limit)
- Memory: 128Mi (request) / 256Mi (limit)

## Security Note

This configuration is intended for local development only. For production use:
- Enable authentication
- Configure proper RBAC permissions
- Use TLS/HTTPS
- Restrict network access

## Troubleshooting

### Cannot access http://headlamp.local

1. Verify Traefik is running:
   ```bash
   kubectl get pods -n traefik
   ```

2. Check if Headlamp pods are running:
   ```bash
   kubectl get pods -n headlamp
   ```

3. Verify the ingress resource:
   ```bash
   kubectl get ingress -n headlamp
   ```

4. Ensure `/etc/hosts` has the entry:
   ```
   127.0.0.1 headlamp.local
   ```

5. Test with curl:
   ```bash
   curl -H "Host: headlamp.local" http://localhost/
   ```

## Documentation

- [Headlamp Official Docs](https://headlamp.dev/docs/)
- [GitHub Repository](https://github.com/headlamp-k8s/headlamp)
