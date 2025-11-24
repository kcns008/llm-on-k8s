# Kimi K2 Instruct 0905 on OpenShift - vLLM Deployment

This repository contains everything you need to deploy the **Kimi K2 Instruct 0905 LLM** (`moonshotai/Kimi-K2-Instruct-0905`) on an OpenShift cluster using vLLM with GPU support.

## What's Included

A complete, production-ready deployment solution for running the Kimi K2 Instruct 0905 model on OpenShift:

- ✅ **Complete Kubernetes manifests** for all required resources
- ✅ **GPU support** (NVIDIA Tesla T4, A10, A100, and better)
- ✅ **vLLM inference engine** with OpenAI-compatible API
- ✅ **Automatic model download** from Hugging Face
- ✅ **Network/Firewall requirements** and security policies
- ✅ **Monitoring and observability** setup
- ✅ **Production-ready configurations** with health checks and resource limits

## Quick Start

### Prerequisites

- OpenShift cluster 4.x with GPU-enabled nodes
- NVIDIA GPU Operator installed
- At least 300GB storage available
- Hugging Face token (get from: https://huggingface.co/settings/tokens)
- `oc` CLI installed and configured

### 30-Second Deployment (CLI)

```bash
# 1. Login to your cluster
oc login --server=https://api.your-cluster.com:6443 --token=YOUR_TOKEN

# 2. Navigate to deployment directory
cd openshift-kimi-k2-0905-vllm

# 3. Create namespace and resources
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-pvc.yaml
oc apply -f manifests/03-configmap.yaml

# 4. Create secret with your HuggingFace token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=your_token_here \
  -n llm-kimi-k2-0905

# 5. Deploy the model
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
oc apply -f manifests/08-networkpolicy.yaml

# 6. Get the API URL
oc get route kimi-k2-0905-vllm -n llm-kimi-k2-0905 -o jsonpath='{.spec.host}'
```

**Note:** Initial deployment takes 35-70 minutes (model download time).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     OpenShift Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────┐      ┌──────────────────────────────┐ │
│  │ OpenShift Route│◄─────┤  External Clients (HTTPS)    │ │
│  └────────┬───────┘      └──────────────────────────────┘ │
│           │                                                 │
│  ┌────────▼───────┐                                        │
│  │    Service     │                                        │
│  │kimi-k2-0905-vllm│                                       │
│  └────────┬───────┘                                        │
│           │                                                 │
│  ┌────────▼────────────────────────────────────────────┐  │
│  │              Pod: kimi-k2-0905-vllm                  │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  Init Container:                                     │  │
│  │  └─ model-downloader (downloads from HuggingFace)    │  │
│  │                                                       │  │
│  │  Main Container:                                     │  │
│  │  └─ vllm-server (serves model via OpenAI-compatible │  │
│  │                   API)                               │  │
│  │                                                       │  │
│  │  Resources:                                          │  │
│  │  • GPU: 1x NVIDIA GPU (16GB+)                       │  │
│  │  • Memory: 32-64 GB                                  │  │
│  │  • CPU: 4-8 cores                                    │  │
│  │                                                       │  │
│  │  Volumes:                                            │  │
│  │  • PVC: kimi-k2-0905-model-cache (300GB)            │  │
│  │  • EmptyDir: /dev/shm (10GB)                        │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | 1x NVIDIA Tesla T4 (16GB) | 1x A100 (40GB+) |
| **Memory** | 32 GB | 64 GB |
| **CPU** | 4 cores | 8 cores |
| **Storage** | 300 GB | 500 GB (SSD) |
| **Network** | 100 Mbps | 1 Gbps |

## API Usage

Once deployed, the model serves an OpenAI-compatible API:

### Get Your Route URL

```bash
ROUTE_URL=$(oc get route kimi-k2-0905-vllm -n llm-kimi-k2-0905 -o jsonpath='{.spec.host}')
echo "API URL: https://$ROUTE_URL"
```

### Health Check

```bash
curl https://$ROUTE_URL/health
```

### List Models

```bash
curl https://$ROUTE_URL/v1/models
```

### Chat Completion

```bash
curl -X POST "https://$ROUTE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "moonshotai/Kimi-K2-Instruct-0905",
    "messages": [
      {
        "role": "user",
        "content": "What is the capital of France?"
      }
    ]
  }'
```

### Local Testing (Port Forward)

If testing locally via port-forward:

```bash
# Forward port to local machine
oc port-forward -n llm-kimi-k2-0905 svc/kimi-k2-0905-vllm 8000:8000

# In another terminal, test the API
curl -X POST "http://localhost:8000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "moonshotai/Kimi-K2-Instruct-0905",
    "messages": [
      {
        "role": "user",
        "content": "What is the capital of France?"
      }
    ]
  }'
```

### Using OpenAI Python SDK

```python
from openai import OpenAI

# Point to your OpenShift route
client = OpenAI(
    base_url="https://your-route-url/v1",
    api_key="not-used"  # vLLM doesn't require API key by default
)

# Chat completion
response = client.chat.completions.create(
    model="moonshotai/Kimi-K2-Instruct-0905",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is the capital of France?"}
    ],
    max_tokens=500,
    temperature=0.7
)

print(response.choices[0].message.content)
```

## Configuration

### Key ConfigMap Settings

Edit `manifests/03-configmap.yaml` to customize:

```yaml
MODEL_NAME: "moonshotai/Kimi-K2-Instruct-0905"  # Model to load
MAX_MODEL_LEN: "16384"                           # Max context length
GPU_MEMORY_UTILIZATION: "0.90"                   # GPU memory usage (0-1)
TENSOR_PARALLEL_SIZE: "1"                        # Number of GPUs
SWAP_SPACE: "16"                                 # CPU swap space (GB)
```

### Supported Context Lengths

The Kimi K2 model supports context lengths up to 128K tokens. However, you may need to adjust based on available GPU memory:

| GPU | Recommended MAX_MODEL_LEN |
|-----|---------------------------|
| Tesla T4 (16GB) | 8192 - 16384 |
| A10/A10G (24GB) | 16384 - 32768 |
| A100 (40GB) | 32768 - 65536 |
| A100 (80GB) | 65536 - 131072 |

## Manifest Files

Located in `manifests/` directory:

| File | Description |
|------|-------------|
| `01-namespace.yaml` | Creates `llm-kimi-k2-0905` namespace |
| `02-pvc.yaml` | Persistent storage for model cache (300GB) |
| `03-configmap.yaml` | vLLM configuration (model name, GPU settings) |
| `04-secret.yaml` | Hugging Face token (template) |
| `05-deployment.yaml` | Main deployment with GPU, init container, health checks |
| `06-service.yaml` | ClusterIP service exposing port 8000 |
| `07-route.yaml` | OpenShift route for external HTTPS access |
| `08-networkpolicy.yaml` | Network policies for security |
| `09-servicemonitor.yaml` | Prometheus monitoring (optional) |

## Monitoring

### Viewing Logs

```bash
# Stream main server logs
oc logs -f -l app=kimi-k2-0905 -c vllm-server -n llm-kimi-k2-0905

# View init container logs (model download)
oc logs -l app=kimi-k2-0905 -c model-downloader -n llm-kimi-k2-0905

# View all containers
oc logs -l app=kimi-k2-0905 --all-containers=true -n llm-kimi-k2-0905
```

### Resource Usage

```bash
# Real-time resource monitoring
oc adm top pod -l app=kimi-k2-0905 -n llm-kimi-k2-0905

# Check deployment status
oc get deployment -n llm-kimi-k2-0905

# Check pod status
oc get pods -n llm-kimi-k2-0905
```

### Prometheus Metrics

If ServiceMonitor is applied, metrics available at:
- `http://kimi-k2-0905-vllm:8000/metrics`

**Key Metrics:**
- `vllm:num_requests_running` - Active requests
- `vllm:gpu_cache_usage_perc` - GPU cache utilization
- `vllm:num_requests_waiting` - Queued requests
- `vllm:time_to_first_token_seconds` - Latency to first token
- `vllm:time_per_output_token_seconds` - Generation speed

## GPU Support

### Supported GPUs

This deployment works with:

- ✅ **Tesla T4** (16GB) - Budget-friendly
- ✅ **Tesla V100** (16/32GB) - Better performance
- ✅ **A10/A10G** (24GB) - Excellent for inference
- ✅ **A100** (40/80GB) - Best performance
- ✅ **RTX 4090** (24GB) - Consumer GPU
- ✅ **RTX 6000 Ada** (48GB) - Workstation GPU

### GPU Setup

Ensure NVIDIA GPU Operator is installed:

```bash
# Check GPU Operator
oc get pods -n nvidia-gpu-operator

# Verify GPU nodes
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU availability
oc describe nodes | grep nvidia.com/gpu
```

## Security

### Network Policies

The deployment includes NetworkPolicies that:
- ✅ Allow ingress only from OpenShift router
- ✅ Allow egress for HTTPS (model download)
- ✅ Allow DNS resolution
- ✅ Deny all other traffic

### Pod Security

- ✅ Runs as non-root user
- ✅ Read-only root filesystem (where possible)
- ✅ Drops all capabilities
- ✅ SeccompProfile: RuntimeDefault

### Secrets Management

- ✅ Hugging Face token stored as Kubernetes Secret
- ✅ Not exposed in logs or environment variable dumps

**Rotate token regularly:**

```bash
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=new_token_here \
  --dry-run=client -o yaml | \
  oc apply -f -

oc rollout restart deployment kimi-k2-0905-vllm -n llm-kimi-k2-0905
```

## Troubleshooting

### Common Issues

#### 1. Pod Stuck in Pending

**Cause:** No GPU available or PVC not bound

**Solution:**
```bash
oc describe pod -l app=kimi-k2-0905 -n llm-kimi-k2-0905 | grep -A 5 Events
```

Check for:
- `Insufficient nvidia.com/gpu` - No GPU nodes available
- `PVC not bound` - Storage provisioning issue

#### 2. Init Container Failing

**Cause:** Cannot download model from Hugging Face

**Solution:**
```bash
oc logs -l app=kimi-k2-0905 -c model-downloader -n llm-kimi-k2-0905
```

Common fixes:
- Verify Hugging Face token is valid
- Check network connectivity
- Verify firewall allows HTTPS to huggingface.co

#### 3. Out of Memory

**Cause:** Model too large for GPU

**Solution:**
- Reduce `MAX_MODEL_LEN` in ConfigMap
- Increase `SWAP_SPACE` for CPU offloading
- Use more GPUs (increase `TENSOR_PARALLEL_SIZE`)

#### 4. Route Not Accessible

**Cause:** Service not ready or route misconfigured

**Solution:**
```bash
# Check service endpoints
oc get endpoints kimi-k2-0905-vllm -n llm-kimi-k2-0905

# Test from inside cluster
oc run curl --image=curlimages/curl -it --rm -- \
  curl http://kimi-k2-0905-vllm.llm-kimi-k2-0905.svc.cluster.local:8000/health
```

## Performance Tuning

### For Tesla T4 (16GB)

```yaml
# ConfigMap settings
MAX_MODEL_LEN: "8192"           # Reduce context for smaller memory
GPU_MEMORY_UTILIZATION: "0.90"
SWAP_SPACE: "16"                # Enable CPU offloading
```

### For A100 (40GB+)

```yaml
# ConfigMap settings
MAX_MODEL_LEN: "32768"          # Larger context length
GPU_MEMORY_UTILIZATION: "0.95"
SWAP_SPACE: "0"                 # Disable CPU offloading
```

### Multi-GPU Setup

```yaml
# ConfigMap settings
TENSOR_PARALLEL_SIZE: "2"       # Use 2 GPUs

# Deployment resources
resources:
  requests:
    nvidia.com/gpu: 2            # Request 2 GPUs
  limits:
    nvidia.com/gpu: 2
```

## Cleanup

### Remove Everything

```bash
# Delete all resources
oc delete -f manifests/

# Or delete namespace (removes everything)
oc delete namespace llm-kimi-k2-0905
```

### Keep Model Cache

If you want to redeploy later without re-downloading:

```bash
# Delete everything except PVCs
oc delete deployment,service,route,configmap,secret -n llm-kimi-k2-0905 --all

# Later, redeploy
oc apply -f manifests/03-configmap.yaml
oc apply -f manifests/04-secret.yaml
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
```

## Model Information

- **Model:** moonshotai/Kimi-K2-Instruct-0905
- **Source:** https://huggingface.co/moonshotai/Kimi-K2-Instruct-0905
- **Context Length:** Up to 128K tokens
- **Type:** Instruction-tuned
- **Provider:** Moonshot AI

## Support and Resources

- **vLLM Documentation**: https://docs.vllm.ai/
- **Kimi K2 on Hugging Face**: https://huggingface.co/moonshotai/Kimi-K2-Instruct-0905
- **OpenShift Documentation**: https://docs.openshift.com/
- **NVIDIA GPU Operator**: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/

## Credits

**Technologies:**
- vLLM - Fast LLM inference engine
- Kimi K2 Instruct 0905 - Open-source LLM by Moonshot AI
- OpenShift - Enterprise Kubernetes platform
- NVIDIA GPUs - Hardware acceleration

---

**Ready to deploy?** Follow the [Quick Start](#quick-start) guide above!
