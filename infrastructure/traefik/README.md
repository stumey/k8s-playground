# Traefik Ingress Controller

Traefik is a modern, cloud-native ingress controller and reverse proxy designed for dynamic environments.

## Features

- Automatic service discovery
- Native Kubernetes integration
- Simple configuration with CRDs
- Low resource footprint
- Built-in Let's Encrypt support
- WebSocket support
- HTTP/2 and gRPC support

## Installation

Traefik is automatically installed during cluster setup via `make setup`.

### Manual Installation

```bash
# Add Traefik Helm repository
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install Traefik
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --values infrastructure/traefik/values.yaml
```

## Configuration

The default configuration:
- Runs on the control-plane node (required for Kind)
- Exposes ports 80 (HTTP) and 443 (HTTPS)
- Uses minimal resources (100m CPU, 64Mi memory)
- NodePort service type

## Ingress Resources

Traefik works with standard Kubernetes Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
spec:
  rules:
  - host: example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

No `ingressClassName` needed - Traefik will handle all ingresses by default.

## Verification

Check Traefik is running:

```bash
kubectl get pods -n traefik
kubectl get svc -n traefik
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n traefik -l app.kubernetes.io/name=traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### Cannot access ingress
1. Verify Traefik is running on control-plane:
   ```bash
   kubectl get pods -n traefik -o wide
   ```
   Should show `playground-control-plane` as the node.

2. Check ingress resource:
   ```bash
   kubectl get ingress --all-namespaces
   ```

3. Verify /etc/hosts entry:
   ```bash
   grep "\.local" /etc/hosts
   ```

## Documentation

- [Traefik Official Docs](https://doc.traefik.io/traefik/)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [Kubernetes Ingress](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
