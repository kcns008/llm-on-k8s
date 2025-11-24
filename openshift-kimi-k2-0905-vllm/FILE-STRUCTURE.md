# File Structure

This document describes the organization of files in this deployment package.

## Directory Structure

```
openshift-kimi-k2-0905-vllm/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # Quick start guide
├── FILE-STRUCTURE.md              # This file
├── manifests/                     # Kubernetes manifests
│   ├── 01-namespace.yaml          # Namespace definition
│   ├── 02-pvc.yaml                # Persistent Volume Claim
│   ├── 03-configmap.yaml          # vLLM configuration
│   ├── 04-secret.yaml             # Hugging Face token (template)
│   ├── 05-deployment.yaml         # Main deployment with vLLM
│   ├── 06-service.yaml            # Kubernetes service
│   ├── 07-route.yaml              # OpenShift route
│   ├── 08-networkpolicy.yaml      # Network policies
│   └── 09-servicemonitor.yaml     # Prometheus monitoring
└── docs/                          # Additional documentation
    └── (future documentation)
```

## File Descriptions

### Root Directory

- **README.md**: Comprehensive documentation covering deployment, configuration, API usage, troubleshooting, and more.
- **QUICKSTART.md**: Step-by-step guide to get started quickly (< 5 minutes).
- **FILE-STRUCTURE.md**: This file - describes the organization of the project.

### manifests/

Kubernetes manifests should be applied in order (01, 02, 03, etc.):

1. **01-namespace.yaml**
   - Creates the `llm-kimi-k2-0905` namespace
   - Labels for organization and management

2. **02-pvc.yaml**
   - Persistent Volume Claim for model cache (300GB)
   - Stores downloaded models to avoid re-downloading

3. **03-configmap.yaml**
   - vLLM configuration parameters
   - Model name, GPU settings, context length
   - Performance tuning options

4. **04-secret.yaml**
   - Template for Hugging Face token
   - Should be created via `oc create secret` command
   - Required for downloading models from Hugging Face

5. **05-deployment.yaml**
   - Main Deployment resource
   - Init container for model download
   - vLLM server container with GPU support
   - Health checks and resource limits

6. **06-service.yaml**
   - ClusterIP service exposing port 8000
   - Session affinity for long-running requests

7. **07-route.yaml**
   - OpenShift Route for external HTTPS access
   - TLS edge termination

8. **08-networkpolicy.yaml**
   - Network security policies
   - Ingress/egress rules

9. **09-servicemonitor.yaml**
   - Prometheus metrics collection (optional)
   - Requires Prometheus Operator

### docs/

Reserved for additional documentation:
- Deployment guides
- Troubleshooting guides
- Network requirements
- Model configuration guides

## Deployment Order

Apply manifests in this order:

```bash
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-pvc.yaml
oc apply -f manifests/03-configmap.yaml
oc create secret generic huggingface-token --from-literal=HF_TOKEN=xxx -n llm-kimi-k2-0905
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
oc apply -f manifests/08-networkpolicy.yaml
oc apply -f manifests/09-servicemonitor.yaml  # optional
```

Or apply all at once:

```bash
oc apply -f manifests/
```

Note: You still need to create the secret manually.

## Configuration Files

### Key Configuration: 03-configmap.yaml

This is the main configuration file you'll modify:

```yaml
MODEL_NAME: "moonshotai/Kimi-K2-Instruct-0905"
MAX_MODEL_LEN: "16384"
GPU_MEMORY_UTILIZATION: "0.90"
TENSOR_PARALLEL_SIZE: "1"
SWAP_SPACE: "16"
```

Adjust these based on your GPU and requirements.

### Secret: 04-secret.yaml

Don't use this template directly in production. Create the secret via CLI:

```bash
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=your_token_here \
  -n llm-kimi-k2-0905
```

## Resource Dependencies

```
Namespace (01)
    ↓
PVC (02) + ConfigMap (03) + Secret (04)
    ↓
Deployment (05)
    ↓
Service (06) + NetworkPolicy (08)
    ↓
Route (07) + ServiceMonitor (09)
```

## Customization Guide

### Change Model

Edit `manifests/03-configmap.yaml`:
```yaml
MODEL_NAME: "your-org/your-model-name"
```

### Adjust GPU Settings

For Tesla T4 (16GB):
```yaml
MAX_MODEL_LEN: "8192"
GPU_MEMORY_UTILIZATION: "0.90"
```

For A100 (40GB+):
```yaml
MAX_MODEL_LEN: "32768"
GPU_MEMORY_UTILIZATION: "0.95"
```

### Multi-GPU Setup

Edit `manifests/03-configmap.yaml`:
```yaml
TENSOR_PARALLEL_SIZE: "2"  # Use 2 GPUs
```

Edit `manifests/05-deployment.yaml`:
```yaml
resources:
  requests:
    nvidia.com/gpu: 2
  limits:
    nvidia.com/gpu: 2
```

## Maintenance

### Update Model

```bash
# Delete deployment
oc delete deployment kimi-k2-0905-vllm -n llm-kimi-k2-0905

# Update configmap if needed
oc apply -f manifests/03-configmap.yaml

# Redeploy
oc apply -f manifests/05-deployment.yaml
```

### Scale Resources

```bash
# Edit deployment
oc edit deployment kimi-k2-0905-vllm -n llm-kimi-k2-0905

# Or update YAML and reapply
oc apply -f manifests/05-deployment.yaml
```

## Clean Up

### Remove Everything

```bash
oc delete -f manifests/
```

Or:

```bash
oc delete namespace llm-kimi-k2-0905
```

### Keep Model Cache

```bash
# Delete resources but keep PVC
oc delete deployment,service,route,configmap,secret,networkpolicy \
  -n llm-kimi-k2-0905 --all
```

---

For more details, see [README.md](README.md) or [QUICKSTART.md](QUICKSTART.md).
