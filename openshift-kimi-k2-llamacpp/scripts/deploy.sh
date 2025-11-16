#!/bin/bash

###############################################################################
# Kimi K2 llama.cpp Deployment Script for OpenShift/ARO
#
# This script automates the deployment of Kimi K2 LLM using llama.cpp
# on Azure Red Hat OpenShift with Tesla T4 GPUs.
#
# Usage:
#   ./scripts/deploy.sh
#
# Prerequisites:
#   - oc CLI installed and logged in
#   - GPU-enabled OpenShift cluster
#   - HuggingFace token
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        exit 1
    fi
}

###############################################################################
# Pre-flight Checks
###############################################################################

preflight_checks() {
    print_header "Pre-flight Checks"

    # Check oc CLI
    print_info "Checking oc CLI..."
    check_command oc
    print_success "oc CLI found"

    # Check if logged in
    print_info "Checking OpenShift login..."
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please run: oc login --server=https://... --token=..."
        exit 1
    fi
    print_success "Logged in as $(oc whoami)"

    # Check cluster version
    print_info "Checking OpenShift version..."
    OCP_VERSION=$(oc version -o json 2>/dev/null | grep -o '"openshiftVersion":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    print_success "OpenShift version: $OCP_VERSION"

    # Check for GPU nodes
    print_info "Checking for GPU nodes..."
    GPU_NODES=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)
    if [ "$GPU_NODES" -eq 0 ]; then
        print_warning "No GPU nodes found (label: nvidia.com/gpu.present=true)"
        print_warning "Deployment may fail if GPU nodes don't exist"
    else
        print_success "Found $GPU_NODES GPU node(s)"
    fi

    # Check GPU Operator
    print_info "Checking NVIDIA GPU Operator..."
    if oc get pods -n nvidia-gpu-operator &> /dev/null; then
        GPU_OPERATOR_PODS=$(oc get pods -n nvidia-gpu-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        print_success "GPU Operator running ($GPU_OPERATOR_PODS pods)"
    else
        print_warning "NVIDIA GPU Operator namespace not found"
        print_warning "Please install GPU Operator from OperatorHub"
    fi

    echo ""
}

###############################################################################
# Configuration
###############################################################################

get_configuration() {
    print_header "Configuration"

    # Get HuggingFace token
    echo -e "${YELLOW}Enter your HuggingFace token:${NC}"
    echo -e "${BLUE}(Get it from: https://huggingface.co/settings/tokens)${NC}"
    read -sp "HF_TOKEN: " HF_TOKEN
    echo ""

    if [ -z "$HF_TOKEN" ]; then
        print_error "HuggingFace token is required"
        exit 1
    fi

    # Choose model variant
    echo ""
    echo -e "${YELLOW}Choose model variant:${NC}"
    echo "1) Kimi-K2-Thinking (recommended, temp=1.0)"
    echo "2) Kimi-K2-Instruct (temp=0.6)"
    read -p "Enter choice [1-2] (default: 1): " MODEL_CHOICE
    MODEL_CHOICE=${MODEL_CHOICE:-1}

    case $MODEL_CHOICE in
        1)
            MODEL_REPO="unsloth/Kimi-K2-Thinking-GGUF"
            TEMPERATURE="1.0"
            SERVED_NAME="kimi-k2-thinking"
            ;;
        2)
            MODEL_REPO="unsloth/Kimi-K2-Instruct-GGUF"
            TEMPERATURE="0.6"
            SERVED_NAME="kimi-k2-instruct"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Choose quantization
    echo ""
    echo -e "${YELLOW}Choose quantization level:${NC}"
    echo "1) UD-TQ1_0 (1.8-bit, 247GB) - Fastest, minimal VRAM"
    echo "2) UD-Q2_K_XL (2.7-bit, 381GB) - Recommended balance"
    echo "3) UD-Q4_K_XL (4.5-bit, 588GB) - Higher quality"
    read -p "Enter choice [1-3] (default: 2): " QUANT_CHOICE
    QUANT_CHOICE=${QUANT_CHOICE:-2}

    case $QUANT_CHOICE in
        1)
            QUANT_TYPE="UD-TQ1_0"
            PVC_SIZE="300Gi"
            ;;
        2)
            QUANT_TYPE="UD-Q2_K_XL"
            PVC_SIZE="450Gi"
            ;;
        3)
            QUANT_TYPE="UD-Q4_K_XL"
            PVC_SIZE="650Gi"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    print_success "Configuration complete"
    print_info "Model: $MODEL_REPO"
    print_info "Quantization: $QUANT_TYPE"
    print_info "PVC Size: $PVC_SIZE"
    echo ""
}

###############################################################################
# Deployment
###############################################################################

deploy_namespace() {
    print_header "Step 1/8: Creating Namespace"

    if oc get namespace llm-models-llamacpp &> /dev/null; then
        print_warning "Namespace llm-models-llamacpp already exists"
    else
        oc apply -f "$MANIFESTS_DIR/01-namespace.yaml"
        print_success "Namespace created"
    fi
    echo ""
}

deploy_pvc() {
    print_header "Step 2/8: Creating Persistent Volume Claim"

    if oc get pvc kimi-k2-gguf-cache -n llm-models-llamacpp &> /dev/null; then
        print_warning "PVC kimi-k2-gguf-cache already exists"
    else
        # Apply with potentially modified size
        cat "$MANIFESTS_DIR/02-pvc.yaml" | \
            sed "s/storage: 400Gi/storage: $PVC_SIZE/" | \
            oc apply -f -
        print_success "PVC created (size: $PVC_SIZE)"

        # Wait for PVC to bind
        print_info "Waiting for PVC to bind..."
        oc wait --for=jsonpath='{.status.phase}'=Bound \
            pvc/kimi-k2-gguf-cache \
            -n llm-models-llamacpp \
            --timeout=120s || print_warning "PVC not bound yet (may take time)"
    fi
    echo ""
}

deploy_configmap() {
    print_header "Step 3/8: Creating ConfigMap"

    # Create modified ConfigMap with user choices
    cat "$MANIFESTS_DIR/03-configmap.yaml" | \
        sed "s|MODEL_REPO: .*|MODEL_REPO: \"$MODEL_REPO\"|" | \
        sed "s|QUANT_TYPE: .*|QUANT_TYPE: \"$QUANT_TYPE\"|" | \
        sed "s|TEMPERATURE: .*|TEMPERATURE: \"$TEMPERATURE\"|" | \
        sed "s|SERVED_MODEL_NAME: .*|SERVED_MODEL_NAME: \"$SERVED_NAME\"|" | \
        oc apply -f -

    print_success "ConfigMap created"
    echo ""
}

deploy_secret() {
    print_header "Step 4/8: Creating Secret"

    if oc get secret huggingface-token -n llm-models-llamacpp &> /dev/null; then
        print_warning "Secret huggingface-token already exists"
        read -p "Replace existing secret? [y/N]: " REPLACE_SECRET
        if [[ $REPLACE_SECRET =~ ^[Yy]$ ]]; then
            oc delete secret huggingface-token -n llm-models-llamacpp
            oc create secret generic huggingface-token \
                --from-literal=HF_TOKEN="$HF_TOKEN" \
                -n llm-models-llamacpp
            print_success "Secret replaced"
        fi
    else
        oc create secret generic huggingface-token \
            --from-literal=HF_TOKEN="$HF_TOKEN" \
            -n llm-models-llamacpp
        print_success "Secret created"
    fi
    echo ""
}

deploy_deployment() {
    print_header "Step 5/8: Creating Deployment"

    oc apply -f "$MANIFESTS_DIR/05-deployment.yaml"
    print_success "Deployment created"
    echo ""
}

deploy_service() {
    print_header "Step 6/8: Creating Service"

    oc apply -f "$MANIFESTS_DIR/06-service.yaml"
    print_success "Service created"
    echo ""
}

deploy_route() {
    print_header "Step 7/8: Creating Route"

    oc apply -f "$MANIFESTS_DIR/07-route.yaml"
    print_success "Route created"
    echo ""
}

deploy_networkpolicy() {
    print_header "Step 8/8: Creating Network Policies (Optional)"

    read -p "Apply network policies? [Y/n]: " APPLY_NP
    APPLY_NP=${APPLY_NP:-Y}

    if [[ $APPLY_NP =~ ^[Yy]$ ]]; then
        oc apply -f "$MANIFESTS_DIR/08-networkpolicy.yaml" || \
            print_warning "Failed to apply network policies (may not be supported)"
        print_success "Network policies applied"
    else
        print_info "Skipping network policies"
    fi
    echo ""
}

###############################################################################
# Post-deployment
###############################################################################

show_status() {
    print_header "Deployment Status"

    # Get pod status
    print_info "Pod status:"
    oc get pods -n llm-models-llamacpp -l app=kimi-k2-llamacpp

    echo ""

    # Get route
    print_info "Getting route URL..."
    ROUTE_URL=$(oc get route kimi-k2-llamacpp -n llm-models-llamacpp -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -n "$ROUTE_URL" ]; then
        print_success "API Endpoint: https://$ROUTE_URL"
    else
        print_warning "Route not ready yet"
    fi

    echo ""
}

show_next_steps() {
    print_header "Next Steps"

    echo "1. Monitor deployment progress:"
    echo -e "   ${GREEN}oc get pods -n llm-models-llamacpp -w${NC}"
    echo ""

    echo "2. Watch init containers (llama.cpp build ~10 min):"
    echo -e "   ${GREEN}oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c build-llamacpp${NC}"
    echo ""

    echo "3. Watch model download (~30-90 min):"
    echo -e "   ${GREEN}oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader${NC}"
    echo ""

    echo "4. Watch server startup:"
    echo -e "   ${GREEN}oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c llama-server${NC}"
    echo ""

    echo "5. Test the API (once ready):"
    if [ -n "$ROUTE_URL" ]; then
        echo -e "   ${GREEN}curl https://$ROUTE_URL/health${NC}"
    else
        echo -e "   ${GREEN}oc get route kimi-k2-llamacpp -n llm-models-llamacpp${NC}"
    fi
    echo ""

    print_info "Full documentation: README.md"
    print_info "Troubleshooting: docs/TROUBLESHOOTING.md"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    clear

    echo ""
    print_header "Kimi K2 llama.cpp Deployment for OpenShift/ARO"
    echo ""

    # Pre-flight checks
    preflight_checks

    # Get configuration
    get_configuration

    # Confirm deployment
    echo ""
    read -p "Proceed with deployment? [Y/n]: " PROCEED
    PROCEED=${PROCEED:-Y}

    if [[ ! $PROCEED =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi

    echo ""

    # Deploy components
    deploy_namespace
    deploy_pvc
    deploy_configmap
    deploy_secret
    deploy_deployment
    deploy_service
    deploy_route
    deploy_networkpolicy

    # Show status
    show_status

    # Show next steps
    show_next_steps

    print_success "Deployment initiated successfully!"
    echo ""
}

# Run main function
main "$@"
