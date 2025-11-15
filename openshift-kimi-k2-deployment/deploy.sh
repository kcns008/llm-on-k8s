#!/bin/bash

################################################################################
# Kimi K2 LLM - Quick Deployment Script for OpenShift
#
# This script automates the deployment of Kimi K2 model on OpenShift cluster
#
# Usage:
#   ./deploy.sh --token YOUR_HF_TOKEN [--namespace llm-models]
#
# Prerequisites:
#   - oc CLI installed and logged in to OpenShift cluster
#   - Cluster with GPU nodes and NVIDIA GPU Operator
#   - At least 300GB storage available
#   - Hugging Face token from https://huggingface.co/settings/tokens
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="llm-models"
HF_TOKEN=""
SKIP_NAMESPACE=false
SKIP_PVC=false
APPLY_NETWORK_POLICY=true
APPLY_SERVICE_MONITOR=false

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Kimi K2 LLM model on OpenShift cluster.

Required Options:
  --token TOKEN               Hugging Face token (required)

Optional Options:
  --namespace NAMESPACE       Kubernetes namespace (default: llm-models)
  --skip-namespace            Skip namespace creation (if already exists)
  --skip-pvc                  Skip PVC creation (if already exists)
  --no-network-policy         Do not apply network policy
  --enable-monitoring         Apply ServiceMonitor for Prometheus
  -h, --help                  Show this help message

Examples:
  # Basic deployment
  $0 --token hf_xxxxxxxxxxxxx

  # Custom namespace
  $0 --token hf_xxxxxxxxxxxxx --namespace my-llm-namespace

  # Skip namespace and PVC (already created)
  $0 --token hf_xxxxxxxxxxxxx --skip-namespace --skip-pvc

  # Enable monitoring
  $0 --token hf_xxxxxxxxxxxxx --enable-monitoring

EOF
    exit 1
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check oc CLI
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi
    print_success "oc CLI found"

    # Check if logged in to OpenShift
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run: oc login"
        exit 1
    fi
    print_success "Logged in to OpenShift as $(oc whoami)"

    # Check cluster connection
    CLUSTER_URL=$(oc whoami --show-server)
    print_success "Connected to cluster: $CLUSTER_URL"

    # Check GPU nodes (warning only)
    GPU_NODES=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$GPU_NODES" -eq 0 ]; then
        print_warning "No GPU nodes found. GPU operator may not be installed."
        print_info "The deployment will be created but may not start without GPU nodes."
    else
        print_success "Found $GPU_NODES GPU node(s)"
    fi

    # Check manifests directory
    if [ ! -d "$MANIFESTS_DIR" ]; then
        print_error "Manifests directory not found: $MANIFESTS_DIR"
        exit 1
    fi
    print_success "Manifests directory found"

    echo ""
}

create_namespace() {
    if [ "$SKIP_NAMESPACE" = true ]; then
        print_info "Skipping namespace creation"
        return
    fi

    print_header "Creating Namespace: $NAMESPACE"

    if oc get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        oc apply -f "$MANIFESTS_DIR/01-namespace.yaml"
        print_success "Namespace created"
    fi

    # Switch to namespace
    oc project "$NAMESPACE"
    print_success "Switched to namespace: $NAMESPACE"
    echo ""
}

create_pvcs() {
    if [ "$SKIP_PVC" = true ]; then
        print_info "Skipping PVC creation"
        return
    fi

    print_header "Creating Persistent Volume Claims"

    oc apply -f "$MANIFESTS_DIR/02-pvc.yaml" -n "$NAMESPACE"

    print_info "Waiting for PVCs to be bound (this may take a moment)..."

    # Wait for PVCs to be bound (timeout 60 seconds)
    timeout=60
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        unbound=$(oc get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "Bound" | wc -l || echo "0")
        if [ "$unbound" -eq 0 ]; then
            print_success "All PVCs are bound"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    if [ $elapsed -ge $timeout ]; then
        print_warning "PVCs may not be bound yet. Check with: oc get pvc -n $NAMESPACE"
    fi

    oc get pvc -n "$NAMESPACE"
    echo ""
}

create_configmap() {
    print_header "Creating ConfigMap"

    oc apply -f "$MANIFESTS_DIR/03-configmap.yaml" -n "$NAMESPACE"
    print_success "ConfigMap created"
    echo ""
}

create_secret() {
    print_header "Creating Hugging Face Secret"

    # Check if secret already exists
    if oc get secret huggingface-token -n "$NAMESPACE" &> /dev/null; then
        print_warning "Secret 'huggingface-token' already exists. Updating..."
        oc delete secret huggingface-token -n "$NAMESPACE"
    fi

    # Create secret from command line (more secure than YAML)
    oc create secret generic huggingface-token \
        --from-literal=HF_TOKEN="$HF_TOKEN" \
        -n "$NAMESPACE"

    print_success "Secret created"
    echo ""
}

deploy_application() {
    print_header "Deploying Kimi K2 vLLM Server"

    oc apply -f "$MANIFESTS_DIR/05-deployment.yaml" -n "$NAMESPACE"
    print_success "Deployment created"

    print_info "Note: Model download will take 30-60 minutes depending on network speed"
    echo ""
}

create_service() {
    print_header "Creating Service"

    oc apply -f "$MANIFESTS_DIR/06-service.yaml" -n "$NAMESPACE"
    print_success "Service created"
    echo ""
}

create_route() {
    print_header "Creating Route (External Access)"

    oc apply -f "$MANIFESTS_DIR/07-route.yaml" -n "$NAMESPACE"
    print_success "Route created"

    # Get route URL
    sleep 2
    ROUTE_URL=$(oc get route kimi-k2-vllm -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "$ROUTE_URL" ]; then
        print_success "API will be available at: https://$ROUTE_URL"
    fi
    echo ""
}

create_network_policy() {
    if [ "$APPLY_NETWORK_POLICY" = false ]; then
        print_info "Skipping Network Policy creation"
        return
    fi

    print_header "Creating Network Policy"

    oc apply -f "$MANIFESTS_DIR/08-networkpolicy.yaml" -n "$NAMESPACE"
    print_success "Network Policy created"
    echo ""
}

create_service_monitor() {
    if [ "$APPLY_SERVICE_MONITOR" = false ]; then
        print_info "Skipping Service Monitor creation"
        return
    fi

    print_header "Creating Service Monitor (Prometheus)"

    if oc apply -f "$MANIFESTS_DIR/09-servicemonitor.yaml" -n "$NAMESPACE" 2>/dev/null; then
        print_success "Service Monitor created"
    else
        print_warning "Failed to create Service Monitor. Prometheus operator may not be installed."
    fi
    echo ""
}

print_deployment_status() {
    print_header "Deployment Status"

    echo "Namespace: $NAMESPACE"
    echo ""

    echo "Pods:"
    oc get pods -n "$NAMESPACE" -l app=kimi-k2 || true
    echo ""

    echo "Services:"
    oc get svc -n "$NAMESPACE" -l app=kimi-k2 || true
    echo ""

    echo "Routes:"
    oc get route -n "$NAMESPACE" || true
    echo ""

    echo "PVCs:"
    oc get pvc -n "$NAMESPACE" || true
    echo ""
}

print_next_steps() {
    print_header "Next Steps"

    ROUTE_URL=$(oc get route kimi-k2-vllm -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    cat << EOF
${GREEN}Deployment initiated successfully!${NC}

${YELLOW}Important:${NC} The deployment will take 35-70 minutes to become fully ready:
  - Model download: 30-60 minutes (downloads ~250GB from Hugging Face)
  - Server startup: 5-10 minutes

${BLUE}Monitor Progress:${NC}

  1. Watch pod status:
     ${YELLOW}oc get pods -n $NAMESPACE -w${NC}

  2. View model download progress (init container):
     ${YELLOW}oc logs -f -l app=kimi-k2 -c model-downloader -n $NAMESPACE${NC}

  3. View server logs:
     ${YELLOW}oc logs -f -l app=kimi-k2 -c vllm-server -n $NAMESPACE${NC}

${BLUE}Access the API:${NC}

  Route URL: ${GREEN}https://$ROUTE_URL${NC}

  Health check:
    ${YELLOW}curl https://$ROUTE_URL/health${NC}

  List models:
    ${YELLOW}curl https://$ROUTE_URL/v1/models${NC}

  Test completion:
    ${YELLOW}curl https://$ROUTE_URL/v1/completions \\
      -H "Content-Type: application/json" \\
      -d '{"model": "kimi-k2", "prompt": "Hello", "max_tokens": 50}'${NC}

${BLUE}Documentation:${NC}

  - CLI Guide: ${YELLOW}docs/DEPLOYMENT-CLI.md${NC}
  - Dashboard Guide: ${YELLOW}docs/DEPLOYMENT-DASHBOARD.md${NC}
  - Network Requirements: ${YELLOW}docs/NETWORK-REQUIREMENTS.md${NC}

${BLUE}Troubleshooting:${NC}

  If pods are not starting:
    ${YELLOW}oc describe pod -l app=kimi-k2 -n $NAMESPACE${NC}

  View all events:
    ${YELLOW}oc get events -n $NAMESPACE --sort-by='.lastTimestamp'${NC}

${GREEN}Happy inferencing!${NC}
EOF
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --token)
                HF_TOKEN="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --skip-namespace)
                SKIP_NAMESPACE=true
                shift
                ;;
            --skip-pvc)
                SKIP_PVC=true
                shift
                ;;
            --no-network-policy)
                APPLY_NETWORK_POLICY=false
                shift
                ;;
            --enable-monitoring)
                APPLY_SERVICE_MONITOR=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$HF_TOKEN" ]; then
        print_error "Hugging Face token is required"
        echo ""
        usage
    fi

    # Banner
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     Kimi K2 LLM Deployment Script for OpenShift              ║
║                                                               ║
║     Deploying open-source LLM with GPU acceleration          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF

    # Execute deployment steps
    check_prerequisites
    create_namespace
    create_pvcs
    create_configmap
    create_secret
    deploy_application
    create_service
    create_route
    create_network_policy
    create_service_monitor
    print_deployment_status
    print_next_steps

    print_success "Deployment script completed!"
}

# Run main function
main "$@"
