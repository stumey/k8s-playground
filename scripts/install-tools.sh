#!/usr/bin/env bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "darwin" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64)     echo "amd64" ;;
        arm64)      echo "arm64" ;;
        aarch64)    echo "arm64" ;;
        *)          echo "unknown" ;;
    esac
}

install_kubectl() {
    if command -v kubectl &> /dev/null; then
        log_info "kubectl is already installed ($(kubectl version --client --short 2>/dev/null || kubectl version --client))"
        return 0
    fi

    log_step "Installing kubectl..."

    local os=$(detect_os)
    local arch=$(detect_arch)

    if [ "$os" = "darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install kubectl
        else
            log_warn "Homebrew not found. Please install kubectl manually."
            log_info "Visit: https://kubernetes.io/docs/tasks/tools/"
        fi
    elif [ "$os" = "linux" ]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${arch}/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    else
        log_error "Unsupported operating system."
        return 1
    fi

    log_info "kubectl installed successfully."
}

install_kind() {
    if command -v kind &> /dev/null; then
        log_info "kind is already installed ($(kind version))"
        return 0
    fi

    log_step "Installing kind..."

    local os=$(detect_os)
    local arch=$(detect_arch)

    if [ "$os" = "darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install kind
        else
            log_warn "Homebrew not found. Installing via curl..."
            curl -Lo ./kind "https://kind.sigs.k8s.io/dl/latest/kind-${os}-${arch}"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
    elif [ "$os" = "linux" ]; then
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/latest/kind-${os}-${arch}"
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    else
        log_error "Unsupported operating system."
        return 1
    fi

    log_info "kind installed successfully."
}

install_helm() {
    if command -v helm &> /dev/null; then
        log_info "helm is already installed ($(helm version --short))"
        return 0
    fi

    log_step "Installing helm..."

    local os=$(detect_os)

    if [ "$os" = "darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install helm
        else
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        fi
    elif [ "$os" = "linux" ]; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    else
        log_error "Unsupported operating system."
        return 1
    fi

    log_info "helm installed successfully."
}

install_k9s() {
    if command -v k9s &> /dev/null; then
        log_info "k9s is already installed ($(k9s version --short))"
        return 0
    fi

    log_step "Installing k9s (Kubernetes CLI UI)..."

    local os=$(detect_os)

    if [ "$os" = "darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install derailed/k9s/k9s
        else
            log_warn "Homebrew not found. Please install k9s manually."
            log_info "Visit: https://k9scli.io/"
        fi
    elif [ "$os" = "linux" ]; then
        if command -v brew &> /dev/null; then
            brew install derailed/k9s/k9s
        else
            log_warn "Please install k9s manually."
            log_info "Visit: https://k9scli.io/"
        fi
    fi

    log_info "k9s installation attempted."
}

show_summary() {
    echo
    log_info "=== Installation Summary ==="
    echo

    local tools=("kubectl" "kind" "helm" "k9s" "docker")

    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} $tool"
        else
            echo -e "  ${RED}✗${NC} $tool (not installed)"
        fi
    done

    echo
    log_info "Note: Docker must be installed separately if not already present."
    log_info "Visit: https://docs.docker.com/get-docker/"
}

main() {
    log_info "Starting installation of Kubernetes tools..."
    echo

    install_kubectl
    install_kind
    install_helm
    install_k9s

    show_summary

    echo
    log_info "✓ Tool installation complete!"
}

main "$@"
