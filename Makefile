.PHONY: help setup teardown clean install-tools cluster-info deploy-sample \
        install-istio install-prometheus install-monitoring install-headlamp \
        install-traefik uninstall-traefik uninstall-headlamp \
        status logs port-forward test validate headlamp

# Configuration
CLUSTER_NAME := playground
NAMESPACE := default

# Colors
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(GREEN)<target>$(RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

install-tools: ## Install required Kubernetes tools (kubectl, kind, helm, k9s)
	@echo "$(GREEN)Installing Kubernetes tools...$(RESET)"
	@./scripts/install-tools.sh

setup: ## Create and configure the Kind cluster
	@echo "$(GREEN)Setting up Kind cluster...$(RESET)"
	@./scripts/setup-cluster.sh

teardown: ## Delete the Kind cluster
	@echo "$(YELLOW)Tearing down Kind cluster...$(RESET)"
	@./scripts/teardown-cluster.sh

clean: teardown ## Clean up all resources (alias for teardown)

##@ Cluster Management

cluster-info: ## Display cluster information
	@echo "$(GREEN)Cluster Information:$(RESET)"
	@kubectl cluster-info
	@echo ""
	@kubectl get nodes -o wide

status: ## Check cluster and pod status
	@echo "$(GREEN)Cluster Status:$(RESET)"
	@kubectl get nodes
	@echo ""
	@echo "$(GREEN)Namespaces:$(RESET)"
	@kubectl get namespaces
	@echo ""
	@echo "$(GREEN)All Pods:$(RESET)"
	@kubectl get pods --all-namespaces

validate: ## Validate cluster health
	@echo "$(GREEN)Validating cluster health...$(RESET)"
	@kubectl get --raw=/healthz
	@kubectl get nodes
	@kubectl get pods --all-namespaces | grep -v Running | grep -v Completed || echo "All pods are healthy"

##@ Application Management

deploy-sample: ## Deploy the sample application
	@echo "$(GREEN)Deploying sample application...$(RESET)"
	@kubectl apply -f apps/sample-app/k8s/manifests/
	@echo "$(GREEN)Sample application deployed!$(RESET)"

delete-sample: ## Delete the sample application
	@echo "$(YELLOW)Deleting sample application...$(RESET)"
	@kubectl delete -f apps/sample-app/k8s/manifests/ --ignore-not-found=true

##@ Infrastructure Tools

install-traefik: ## Install Traefik ingress controller
	@echo "$(GREEN)Installing Traefik...$(RESET)"
	@helm repo list | grep -q traefik || helm repo add traefik https://traefik.github.io/charts
	@helm repo update
	@helm upgrade --install traefik traefik/traefik \
		--namespace traefik \
		--create-namespace \
		--values infrastructure/traefik/values.yaml
	@echo "$(GREEN)Traefik installed!$(RESET)"

uninstall-traefik: ## Uninstall Traefik
	@echo "$(YELLOW)Uninstalling Traefik...$(RESET)"
	@helm uninstall traefik -n traefik || true
	@kubectl delete namespace traefik --ignore-not-found=true

install-istio: ## Install Istio service mesh
	@echo "$(GREEN)Installing Istio...$(RESET)"
	@kubectl apply -f infrastructure/istio/

install-prometheus: ## Install Prometheus monitoring stack
	@echo "$(GREEN)Installing Prometheus...$(RESET)"
	@kubectl apply -f infrastructure/prometheus/

install-monitoring: ## Install complete monitoring stack
	@echo "$(GREEN)Installing monitoring stack...$(RESET)"
	@kubectl apply -f infrastructure/monitoring/

install-headlamp: ## Install Headlamp Kubernetes UI
	@echo "$(GREEN)Installing Headlamp...$(RESET)"
	@helm repo list | grep -q headlamp || helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
	@helm repo update
	@helm upgrade --install headlamp headlamp/headlamp \
		--namespace headlamp \
		--create-namespace \
		--values infrastructure/headlamp/values.yaml
	@echo "$(GREEN)Headlamp installed!$(RESET)"
	@echo ""
	@echo "$(YELLOW)Add this entry to /etc/hosts:$(RESET)"
	@echo "  127.0.0.1 headlamp.local"
	@echo ""
	@echo "$(GREEN)Access Headlamp at: http://headlamp.local$(RESET)"

uninstall-headlamp: ## Uninstall Headlamp
	@echo "$(YELLOW)Uninstalling Headlamp...$(RESET)"
	@helm uninstall headlamp -n headlamp || true
	@kubectl delete namespace headlamp --ignore-not-found=true

##@ Development

logs: ## Tail logs from all pods in default namespace
	@kubectl logs -f --all-containers=true -l app --namespace=$(NAMESPACE)

port-forward: ## Port-forward sample app (adjust as needed)
	@echo "$(GREEN)Port-forwarding sample app on localhost:8080$(RESET)"
	@kubectl port-forward -n $(NAMESPACE) svc/sample-app 8080:80

shell: ## Open a shell in a pod (usage: make shell POD=pod-name)
	@kubectl exec -it $(POD) -n $(NAMESPACE) -- /bin/sh

##@ Testing

test: ## Run basic cluster tests
	@echo "$(GREEN)Running cluster tests...$(RESET)"
	@kubectl run test-pod --image=busybox --rm -it --restart=Never -- echo "Cluster is working!"

##@ Utilities

watch: ## Watch all resources in the cluster
	@kubectl get all --all-namespaces --watch

k9s: ## Launch k9s terminal UI
	@k9s

headlamp: ## Open Headlamp in browser (requires /etc/hosts entry)
	@echo "$(GREEN)Opening Headlamp UI...$(RESET)"
	@echo "If Headlamp doesn't open, ensure you have added to /etc/hosts:"
	@echo "  127.0.0.1 headlamp.local"
	@open http://headlamp.local 2>/dev/null || xdg-open http://headlamp.local 2>/dev/null || echo "Please open http://headlamp.local in your browser"

ctx: ## Show current Kubernetes context
	@kubectl config current-context

ns: ## List all namespaces
	@kubectl get namespaces
