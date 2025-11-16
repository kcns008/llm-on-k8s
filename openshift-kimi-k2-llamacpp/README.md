# Kimi K2 on ARO with llama.cpp - Deployment Package

Deploy **Kimi K2 LLM** on Azure Red Hat OpenShift (ARO) using **llama.cpp** and optimized **GGUF quantized models** for **Tesla T4 GPUs**.

## What's Included

A complete, production-ready deployment for running Kimi K2 with llama.cpp on OpenShift:

- ✅ **llama.cpp inference engine** (built from source with CUDA support)
- ✅ **GGUF quantized models** (1.8-bit to 5.5-bit options)
- ✅ **Tesla T4 optimized** with MoE layer CPU offloading
- ✅ **OpenAI-compatible API** via llama-server
- ✅ **Complete Kubernetes manifests** for all resources
- ✅ **Automatic model download** from Unsloth's GGUF repository
- ✅ **Detailed deployment guides** and configuration docs
- ✅ **Network policies and security** best practices
- ✅ **Production-ready** with health checks and monitoring

## Why llama.cpp + GGUF?

| Feature | llama.cpp + GGUF | vLLM |
|---------|------------------|------|
| **Model Size** | 247GB (1.8-bit quant) | 1TB+ (full precision) |
| **VRAM Required** | ~8GB (with MoE offloading) | 40GB+ |
| **Tesla T4 Compatible** | ✅ Yes | ❌ Needs multiple GPUs |
| **Quantization** | Multiple options (1-5 bit) | Limited |
| **Setup Complexity** | Moderate | Simple |
| **Performance** | 1-5 tokens/s (T4) | 10-20 tokens/s (A100) |

**Perfect for:** Cost-effective inference on Tesla T4, experimentation, and edge deployments.

## Quick Start

### Prerequisites

- **OpenShift/ARO cluster** 4.x with GPU-enabled nodes (Tesla T4)
- **NVIDIA GPU Operator** installed
- **400GB+ storage** available (for model cache)
- **Hugging Face token** (get from: https://huggingface.co/settings/tokens)
- **`oc` CLI** installed and configured

### 5-Minute Deployment

```bash
# 1. Login to your cluster
oc login --server=https://api.your-cluster.com:6443 --token=YOUR_TOKEN

# 2. Navigate to deployment directory
cd openshift-kimi-k2-llamacpp

# 3. Create namespace and storage
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-pvc.yaml

# 4. Create configuration
oc apply -f manifests/03-configmap.yaml

# 5. Create secret with your HuggingFace token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=your_token_here \
  -n llm-models-llamacpp

# 6. Deploy the service
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
oc apply -f manifests/08-networkpolicy.yaml

# 7. Get the API URL
oc get route kimi-k2-llamacpp -n llm-models-llamacpp -o jsonpath='{.spec.host}'
```

**Initial deployment time:** 45-90 minutes (llama.cpp build: 10-15 min, model download: 30-75 min)

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                  Azure Red Hat OpenShift                       │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────┐      ┌────────────────────────────────┐    │
│  │ Route (HTTPS)│◄─────┤  External Clients              │    │
│  └──────┬───────┘      └────────────────────────────────┘    │
│         │                                                      │
│  ┌──────▼──────────┐                                          │
│  │    Service      │                                          │
│  │ kimi-k2-llamacpp│                                          │
│  └──────┬──────────┘                                          │
│         │                                                      │
│  ┌──────▼──────────────────────────────────────────────────┐ │
│  │              Pod: kimi-k2-llamacpp                       │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │  Init Containers:                                        │ │
│  │  1. build-llamacpp (builds llama.cpp with CUDA)         │ │
│  │  2. model-downloader (downloads GGUF from Unsloth)      │ │
│  │                                                          │ │
│  │  Main Container:                                         │ │
│  │  └─ llama-server (OpenAI-compatible API)                │ │
│  │     • MoE layers offloaded to CPU                       │ │
│  │     • Non-MoE layers on GPU                             │ │
│  │                                                          │ │
│  │  Resources:                                              │ │
│  │  • GPU: 1x NVIDIA Tesla T4 (16GB)                       │ │
│  │  • RAM: 64-128 GB (for MoE offloading)                  │ │
│  │  • CPU: 8-16 cores                                       │ │
│  │                                                          │ │
│  │  Volumes:                                                │ │
│  │  • PVC: kimi-k2-gguf-cache (400GB) - GGUF models       │ │
│  │  • EmptyDir: llamacpp-bin - llama.cpp binaries         │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Model Options

Choose your quantization level in `03-configmap.yaml`:

| Quantization | Size | VRAM (w/ offload) | Quality | Speed |
|--------------|------|-------------------|---------|-------|
| **UD-TQ1_0** | 247GB | ~8GB | Good | Fastest |
| **UD-IQ1_S** | 281GB | ~9GB | Better | Fast |
| **UD-Q2_K_XL** ⭐ | 381GB | ~12GB | Best | Medium |
| **UD-Q4_K_XL** | 588GB | ~18GB | Excellent | Slower |

⭐ **Recommended:** `UD-Q2_K_XL` for best balance of quality and size

**Two model variants:**
- **Kimi-K2-Thinking** - For reasoning tasks (temperature: 1.0)
- **Kimi-K2-Instruct** - For general tasks (temperature: 0.6)

## Resource Requirements

### Minimum Configuration (Tesla T4)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | 1x Tesla T4 (16GB) | 1x A10/A10G (24GB) |
| **Memory** | 64 GB | 128 GB |
| **CPU** | 8 cores | 16 cores |
| **Storage** | 300 GB | 500 GB SSD |
| **Network** | 100 Mbps | 1 Gbps |

### Performance Expectations

**Tesla T4 (16GB) with MoE offloading:**
- Context length: 16K tokens
- Speed: 1-2 tokens/second
- Concurrent requests: 1-2

**A10/A10G (24GB) with partial offloading:**
- Context length: 32K tokens
- Speed: 3-5 tokens/second
- Concurrent requests: 2-4

## API Usage

The deployment provides an OpenAI-compatible API:

### Test the API

```bash
# Get your route URL
ROUTE_URL=$(oc get route kimi-k2-llamacpp -n llm-models-llamacpp -o jsonpath='{.spec.host}')

# Health check
curl https://$ROUTE_URL/health

# List models
curl https://$ROUTE_URL/v1/models

# Chat completion
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2-thinking",
    "messages": [
      {"role": "system", "content": "You are Kimi, an AI assistant created by Moonshot AI."},
      {"role": "user", "content": "Explain quantum entanglement simply."}
    ],
    "max_tokens": 500,
    "temperature": 1.0,
    "min_p": 0.01
  }'
```

### Python Example

```python
from openai import OpenAI

# Point to your OpenShift route
client = OpenAI(
    base_url="https://your-route-url/v1",
    api_key="not-needed"  # llama-server doesn't require API key
)

# Chat completion
response = client.chat.completions.create(
    model="kimi-k2-thinking",
    messages=[
        {"role": "system", "content": "You are Kimi, an AI assistant."},
        {"role": "user", "content": "What is the meaning of life?"}
    ],
    temperature=1.0,
    max_tokens=1000
)

print(response.choices[0].message.content)
```

## Configuration

### Switching Models

Edit `manifests/03-configmap.yaml`:

```yaml
# For Thinking model
MODEL_REPO: "unsloth/Kimi-K2-Thinking-GGUF"
TEMPERATURE: "1.0"

# For Instruct model
MODEL_REPO: "unsloth/Kimi-K2-Instruct-GGUF"
TEMPERATURE: "0.6"
```

### Adjusting Quantization

```yaml
# Smaller, faster (247GB)
QUANT_TYPE: "UD-TQ1_0"

# Balanced (381GB)
QUANT_TYPE: "UD-Q2_K_XL"

# Higher quality (588GB)
QUANT_TYPE: "UD-Q4_K_XL"
```

### MoE Offloading Strategies

```yaml
# Maximum offloading - uses least VRAM (~8GB)
MoE_OFFLOAD: ".ffn_.*_exps.=CPU"

# Moderate offloading (~12GB VRAM)
MoE_OFFLOAD: ".ffn_(up|down)_exps.=CPU"

# Minimal offloading (~16GB VRAM)
MoE_OFFLOAD: ".ffn_(up)_exps.=CPU"

# No offloading (requires 247GB+ VRAM!)
MoE_OFFLOAD: ""
```

## Documentation

- **[Quickstart Guide](QUICKSTART.md)** - Get started in 5 minutes
- **[Deployment Guide](docs/DEPLOYMENT-CLI.md)** - Detailed step-by-step instructions
- **[Model Quantizations](docs/MODEL-QUANTIZATIONS.md)** - Understanding GGUF quants
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## Monitoring

### Check Deployment Status

```bash
# Pod status
oc get pods -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# Watch init containers progress
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c build-llamacpp
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader

# Main server logs
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c llama-server

# Resource usage
oc adm top pod -n llm-models-llamacpp
```

### GPU Monitoring

```bash
# Get GPU node
GPU_NODE=$(oc get pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp \
  -o jsonpath='{.items[0].spec.nodeName}')

# Check GPU usage
oc debug node/$GPU_NODE -- chroot /host nvidia-smi
```

## Troubleshooting

### Common Issues

#### 1. Init Container `build-llamacpp` Failing

**Symptom:** Build fails during compilation

**Solution:**
```bash
# Check logs
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c build-llamacpp

# Common fix: Increase memory limits in deployment
# Edit 05-deployment.yaml, increase build-llamacpp memory to 16Gi
```

#### 2. Model Download Slow/Timeout

**Symptom:** `model-downloader` takes too long or times out

**Solution:**
```bash
# The download can take 30-90 minutes for large quants
# Check progress:
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader

# If timeout, increase init container timeout or download manually
```

#### 3. Out of Memory

**Symptom:** Pod killed due to OOM

**Solutions:**
1. Use smaller quantization (`UD-TQ1_0` instead of `UD-Q2_K_XL`)
2. Increase memory limits in deployment
3. Ensure MoE offloading is enabled
4. Reduce context size (`CTX_SIZE: "8192"`)

#### 4. Slow Inference

**Symptom:** Less than 1 token/second

**Solutions:**
1. Reduce MoE offloading (but needs more VRAM)
2. Increase CPU cores allocation
3. Use faster storage (SSD instead of HDD)
4. Reduce concurrent requests

## Performance Tuning

### For Tesla T4 (16GB VRAM)

```yaml
# ConfigMap optimizations
QUANT_TYPE: "UD-TQ1_0"        # Smallest quant
CTX_SIZE: "8192"               # Smaller context
N_GPU_LAYERS: "99"             # Offload all non-MoE
MoE_OFFLOAD: ".ffn_.*_exps.=CPU"  # Full MoE offload
THREADS: "-1"                  # Use all CPUs
```

### For A10/A10G (24GB VRAM)

```yaml
# ConfigMap optimizations
QUANT_TYPE: "UD-Q2_K_XL"      # Balanced quant
CTX_SIZE: "32768"              # Larger context
N_GPU_LAYERS: "99"             # Offload all non-MoE
MoE_OFFLOAD: ".ffn_(up|down)_exps.=CPU"  # Partial MoE offload
```

## Cleanup

### Remove Everything

```bash
# Delete all resources
oc delete -f manifests/

# Or delete namespace (removes everything)
oc delete namespace llm-models-llamacpp
```

### Keep Model Cache

To avoid re-downloading:

```bash
# Delete everything except PVC
oc delete deployment,service,route,configmap,secret,networkpolicy \
  -n llm-models-llamacpp --all

# Later, redeploy without re-downloading
oc apply -f manifests/03-configmap.yaml
oc create secret generic huggingface-token --from-literal=HF_TOKEN=xxx -n llm-models-llamacpp
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
```

## Comparison with vLLM Deployment

| Feature | llama.cpp (This) | vLLM |
|---------|------------------|------|
| **Best For** | Tesla T4, cost-sensitive | A100, high performance |
| **Model Size** | 247GB-381GB (GGUF) | 1TB+ (full precision) |
| **VRAM Usage** | 8-16GB | 40GB+ |
| **Setup Time** | 45-90 min | 30-60 min |
| **Performance** | 1-5 tok/s | 10-20 tok/s |
| **Flexibility** | High (many quants) | Medium |
| **Production Ready** | ✅ Yes | ✅ Yes |

## Credits & Resources

**Technologies:**
- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Efficient LLM inference
- [Unsloth GGUF Models](https://huggingface.co/unsloth) - Optimized quantizations
- [Kimi K2](https://huggingface.co/moonshotai/Kimi-K2-Thinking) - Moonshot AI's LLM
- [Azure Red Hat OpenShift](https://azure.microsoft.com/en-us/products/openshift) - Enterprise Kubernetes

**Documentation:**
- [llama.cpp docs](https://github.com/ggml-org/llama.cpp/tree/master/docs)
- [Unsloth Kimi K2 Guide](https://docs.unsloth.ai/tutorials/how-to-run/kimi-k2)
- [OpenShift GPU docs](https://docs.openshift.com/container-platform/latest/architecture/nvidia-gpu-architecture-overview.html)

---

**Ready to deploy?** Start with the [Quickstart Guide](QUICKSTART.md)!
