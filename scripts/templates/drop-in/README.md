# Drop-in Templates for External Projects

These templates are designed to be copied into YOUR application repositories to quickly integrate with the k8s-playground cluster.

## Quick Start

### Option 1: Use the deploy script (No setup needed)

```bash
# From the k8s-playground repo
./scripts/deploy-external-app.sh ~/path/to/your/app

# That's it! Auto-detects everything and deploys
```

### Option 2: Add Skaffold to your project

1. **Copy the appropriate Skaffold template:**

   ```bash
   # If you have a Helm chart
   cp scripts/templates/drop-in/skaffold-helm.yaml ~/your-app/skaffold.yaml

   # If you have k8s manifests
   cp scripts/templates/drop-in/skaffold-manifests.yaml ~/your-app/skaffold.yaml
   ```

2. **Customize the file:**
   - Replace `my-app` with your actual app name
   - Adjust ports, paths, and sync patterns

3. **Deploy:**
   ```bash
   cd ~/your-app
   skaffold dev  # Continuous development with auto-rebuild
   skaffold run  # One-time deployment
   ```

### Option 3: Use the minimal Helm chart

If you don't have Helm charts yet, copy the minimal template:

```bash
cp -r scripts/templates/helm ~/your-app/helm
```

Customize `helm/values-local.yaml` for your needs.

## What You Need in Your App

### Minimum Requirements

- **Dockerfile** - For building your container image
- **That's it!** The deploy script can generate minimal k8s resources

### Optional (for better experience)

- **Helm chart** (`helm/`) - For parameterized deployments
- **K8s manifests** (`k8s/` or `manifests/`) - For direct kubectl deployment
- **skaffold.yaml** - For continuous development workflow

## Language-Specific Starters

Need a starting point? Check out `scripts/templates/starters/`:

- `nodejs/` - Node.js HTTP server template
- `dotnet/` - .NET 8 Minimal API template
- `go/` - Go net/http server template

Copy the entire directory to start a new project:

```bash
cp -r scripts/templates/starters/nodejs ~/my-new-app
cd ~/my-new-app
# Customize and develop
```

Then deploy it:

```bash
# From k8s-playground repo
./scripts/deploy-external-app.sh ~/my-new-app
```

## Common Workflows

### Development Mode (Hot Reload)

```bash
cd ~/your-app
skaffold dev --profile=debug
```

File changes auto-sync without rebuilding the image.

### One-Time Deploy

```bash
cd ~/your-app
skaffold run
```

Or use the deploy script:

```bash
./scripts/deploy-external-app.sh ~/your-app
```

### Build Only (No Deploy)

```bash
./scripts/deploy-external-app.sh ~/your-app --build-only
```

Builds and loads image into Kind, but doesn't deploy.

### Cleanup

```bash
cd ~/your-app
skaffold delete
```

Or:

```bash
./scripts/deploy-external-app.sh ~/your-app --cleanup
```

## Tips

1. **Add to /etc/hosts:**
   ```bash
   echo "127.0.0.1 your-app.local" | sudo tee -a /etc/hosts
   ```

2. **Use values-local.yaml** for Kind-specific settings:
   - Lower resource limits
   - `imagePullPolicy: IfNotPresent`
   - Debug logging
   - Single replica

3. **Use values.yaml** for production settings:
   - Higher resource limits
   - `imagePullPolicy: Always`
   - Multiple replicas
   - Autoscaling enabled

4. **Port forwarding** is automatic with Skaffold, or manual:
   ```bash
   kubectl port-forward svc/your-app 8080:80
   ```
