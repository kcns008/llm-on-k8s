# Kimi K2 LLM on OpenShift - Complete Deployment Package

This repository contains everything you need to deploy the **Kimi K2 Large Language Model** on an OpenShift cluster with GPU support (NVIDIA Tesla T4 and better).

## What's Included

A complete, production-ready deployment solution for running open-source LLM models on OpenShift:

- ✅ **Complete Kubernetes manifests** for all required resources
- ✅ **GPU support** (NVIDIA Tesla T4 optimized)
- ✅ **Detailed deployment guides** for both CLI and Web Console
- ✅ **Network/Firewall requirements** documentation
- ✅ **Monitoring and observability** setup
- ✅ **Security best practices** (NetworkPolicies, RBAC, secrets)
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
cd openshift-kimi-k2-deployment

# 3. Create namespace and resources
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-pvc.yaml
oc apply -f manifests/03-configmap.yaml

# 4. Create secret with your HuggingFace token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=your_token_here \
  -n llm-models

# 5. Deploy the model
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml

# 6. Get the API URL
oc get route kimi-k2-vllm -n llm-models -o jsonpath='{.spec.host}'
```

**Note:** Initial deployment takes 35-70 minutes (model download time).

## Documentation

### 📖 Deployment Guides

- **[CLI Deployment Guide](docs/DEPLOYMENT-CLI.md)** - Step-by-step guide using `oc` command-line tool
  - Prerequisites and requirements
  - Complete deployment steps
  - Verification and testing
  - Troubleshooting
  - Scaling and updates

- **[Dashboard Deployment Guide](docs/DEPLOYMENT-DASHBOARD.md)** - Step-by-step guide using OpenShift Web Console
  - UI-based deployment
  - Screenshots and visual guidance
  - Monitoring and observability
  - Common questions

### 🌐 Network Requirements

- **[Network & Firewall Requirements](docs/NETWORK-REQUIREMENTS.md)** - Complete network setup guide
  - Required outbound access (Hugging Face, Docker Hub, PyPI)
  - Firewall rules and ports
  - Bandwidth requirements
  - Proxy configuration
  - Cloud-specific security groups (AWS, Azure, GCP)
  - Troubleshooting network issues

## Architecture

### Components

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
│  │ kimi-k2-vllm   │                                        │
│  └────────┬───────┘                                        │
│           │                                                 │
│  ┌────────▼────────────────────────────────────────────┐  │
│  │              Pod: kimi-k2-vllm                       │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  Init Container:                                     │  │
│  │  └─ model-downloader (downloads from HuggingFace)    │  │
│  │                                                       │  │
│  │  Main Container:                                     │  │
│  │  └─ vllm-server (serves model via OpenAI-compatible │  │
│  │                   API)                               │  │
│  │                                                       │  │
│  │  Resources:                                          │  │
│  │  • GPU: 1x NVIDIA Tesla T4 (16GB)                   │  │
│  │  • Memory: 32-64 GB                                  │  │
│  │  • CPU: 4-8 cores                                    │  │
│  │                                                       │  │
│  │  Volumes:                                            │  │
│  │  • PVC: kimi-k2-model-cache (300GB)                 │  │
│  │  • EmptyDir: /dev/shm (10GB)                        │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | 1x NVIDIA Tesla T4 (16GB) | 1x A100 (40GB+) |
| **Memory** | 32 GB | 64 GB |
| **CPU** | 4 cores | 8 cores |
| **Storage** | 300 GB | 500 GB (SSD) |
| **Network** | 100 Mbps | 1 Gbps |

## Manifest Files

Located in `manifests/` directory:

| File | Description |
|------|-------------|
| `01-namespace.yaml` | Creates `llm-models` namespace |
| `02-pvc.yaml` | Persistent storage for model cache (300GB) |
| `03-configmap.yaml` | vLLM configuration (model name, GPU settings) |
| `04-secret.yaml` | Hugging Face token (template) |
| `05-deployment.yaml` | Main deployment with GPU, init container, health checks |
| `06-service.yaml` | ClusterIP service exposing port 8000 |
| `07-route.yaml` | OpenShift route for external HTTPS access |
| `08-networkpolicy.yaml` | Network policies for security |
| `09-servicemonitor.yaml` | Prometheus monitoring (optional) |

## Configuration

### Key ConfigMap Settings

Edit `manifests/03-configmap.yaml` to customize:

```yaml
MODEL_NAME: "moonshotai/Kimi-K2-Instruct"  # Model to load
MAX_MODEL_LEN: "8192"                       # Max context length
GPU_MEMORY_UTILIZATION: "0.90"              # GPU memory usage (0-1)
TENSOR_PARALLEL_SIZE: "1"                   # Number of GPUs
SWAP_SPACE: "16"                            # CPU swap space (GB)
```

### Supported Models

While this package is configured for Kimi K2, you can easily deploy other models by changing `MODEL_NAME`:

- `moonshotai/Kimi-K2-Instruct` - Instruction-tuned model
- `moonshotai/Kimi-K2-Thinking` - Thinking/reasoning model
- `meta-llama/Llama-2-7b-chat-hf` - Llama 2 7B
- `mistralai/Mistral-7B-Instruct-v0.2` - Mistral 7B
- Any vLLM-compatible HuggingFace model

**Note:** Adjust resource limits based on model size.

## API Usage

Once deployed, the model serves an OpenAI-compatible API:

### Health Check

```bash
curl https://your-route-url/health
```

### List Models

```bash
curl https://your-route-url/v1/models
```

### Chat Completion

```bash
curl https://your-route-url/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain quantum computing."}
    ],
    "max_tokens": 500,
    "temperature": 0.7
  }'
```

### Text Completion

```bash
curl https://your-route-url/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "prompt": "Once upon a time",
    "max_tokens": 100
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
    model="kimi-k2",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is the capital of France?"}
    ]
)

print(response.choices[0].message.content)
```

## GPU Support

### Supported GPUs

This deployment is optimized for NVIDIA Tesla T4 (16GB VRAM), but works with:

- ✅ **Tesla T4** (16GB) - Budget-friendly, tested
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

If GPU Operator is not installed:

```bash
# Install GPU Operator via OperatorHub
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: stable
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
```

## Monitoring

### Prometheus Metrics

If ServiceMonitor is applied, metrics available at:
- `http://kimi-k2-vllm:8000/metrics`

**Key Metrics:**
- `vllm:num_requests_running` - Active requests
- `vllm:gpu_cache_usage_perc` - GPU cache utilization
- `vllm:num_requests_waiting` - Queued requests
- `vllm:time_to_first_token_seconds` - Latency to first token
- `vllm:time_per_output_token_seconds` - Generation speed

### Viewing Logs

```bash
# Stream logs
oc logs -f -l app=kimi-k2 -c vllm-server -n llm-models

# View init container logs (model download)
oc logs -l app=kimi-k2 -c model-downloader -n llm-models

# View all containers
oc logs -l app=kimi-k2 --all-containers=true -n llm-models
```

### Resource Usage

```bash
# Real-time resource monitoring
oc adm top pod -l app=kimi-k2 -n llm-models

# Node GPU usage
nvidia-smi  # Run on GPU node
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
- ✅ Recommend using external secrets manager (Vault, AWS Secrets Manager)

**Rotate token regularly:**

```bash
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=new_token_here \
  --dry-run=client -o yaml | \
  oc apply -f -

oc rollout restart deployment kimi-k2-vllm -n llm-models
```

## Troubleshooting

### Common Issues

#### 1. Pod Stuck in Pending

**Cause:** No GPU available or PVC not bound

**Solution:**
```bash
oc describe pod -l app=kimi-k2 -n llm-models | grep -A 5 Events
```

Check for:
- `Insufficient nvidia.com/gpu` - No GPU nodes available
- `PVC not bound` - Storage provisioning issue

#### 2. Init Container Failing

**Cause:** Cannot download model from Hugging Face

**Solution:**
```bash
oc logs -l app=kimi-k2 -c model-downloader -n llm-models
```

Common fixes:
- Verify Hugging Face token is valid
- Check network connectivity (see Network Requirements doc)
- Verify firewall allows HTTPS to huggingface.co

#### 3. Out of Memory

**Cause:** Model too large for GPU

**Solution:**
- Reduce `MAX_MODEL_LEN` in ConfigMap
- Increase `SWAP_SPACE` for CPU offloading
- Use smaller model or more GPUs

#### 4. Route Not Accessible

**Cause:** Service not ready or route misconfigured

**Solution:**
```bash
# Check service endpoints
oc get endpoints kimi-k2-vllm -n llm-models

# Test from inside cluster
oc run curl --image=curlimages/curl -it --rm -- \
  curl http://kimi-k2-vllm.llm-models.svc.cluster.local:8000/health
```

### Getting Help

1. Check logs: `oc logs -l app=kimi-k2 --all-containers -n llm-models`
2. Check events: `oc get events -n llm-models --sort-by='.lastTimestamp'`
3. Describe pod: `oc describe pod -l app=kimi-k2 -n llm-models`
4. Review documentation in `docs/` directory

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
MAX_MODEL_LEN: "32768"          # Full context length
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
oc delete namespace llm-models
```

### Keep Model Cache

If you want to redeploy later without re-downloading:

```bash
# Delete everything except PVCs
oc delete deployment,service,route,configmap,secret -n llm-models --all

# Later, redeploy
oc apply -f manifests/03-configmap.yaml
oc apply -f manifests/04-secret.yaml
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
```

## Production Checklist

Before going to production:

- [ ] Use specific image tag (not `latest`): `vllm/vllm-openai:v0.5.0`
- [ ] Set up authentication (OAuth proxy, API gateway)
- [ ] Configure resource quotas and limits
- [ ] Enable monitoring and alerting
- [ ] Set up log aggregation
- [ ] Configure backup for model cache
- [ ] Use valid SSL certificates (not self-signed)
- [ ] Implement rate limiting
- [ ] Set up autoscaling (HPA)
- [ ] Document runbook for on-call team
- [ ] Perform load testing
- [ ] Set up disaster recovery plan

## Contributing

This is a reference deployment. To customize:

1. Fork or copy this repository
2. Modify manifests for your environment
3. Update ConfigMaps for different models
4. Add your own monitoring/logging integrations
5. Implement authentication layer

## License

This deployment package is provided as-is for educational and production use.

**Components:**
- vLLM: Apache 2.0 License
- Kimi K2 Model: Check Hugging Face model card for license
- OpenShift: Red Hat OpenShift License

## Support and Resources

- **vLLM Documentation**: https://docs.vllm.ai/
- **Kimi K2 on Hugging Face**: https://huggingface.co/moonshotai/Kimi-K2-Instruct
- **OpenShift Documentation**: https://docs.openshift.com/
- **NVIDIA GPU Operator**: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/

## Credits

Created for deploying open-source LLM models on OpenShift with enterprise-grade reliability.

**Technologies:**
- vLLM - Fast LLM inference engine
- Kimi K2 - Open-source LLM by Moonshot AI
- OpenShift - Enterprise Kubernetes platform
- NVIDIA GPUs - Hardware acceleration

---

**Ready to deploy?** Start with the [CLI Deployment Guide](docs/DEPLOYMENT-CLI.md) or [Dashboard Guide](docs/DEPLOYMENT-DASHBOARD.md)!
