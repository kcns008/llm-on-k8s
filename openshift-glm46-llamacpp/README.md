# GLM-4.6 on ARO with llama.cpp - Deployment Package

Deploy **GLM-4.6 LLM** (Z.ai's latest reasoning model) on Azure Red Hat OpenShift (ARO) using **llama.cpp** and optimized **GGUF quantized models** for **Tesla T4 GPUs**.

## What's Included

A complete, production-ready deployment for running GLM-4.6 with llama.cpp on OpenShift:

- ✅ **llama.cpp inference engine** (built from source with CUDA support)
- ✅ **GGUF quantized models** (1.66-bit to 5.5-bit options from Unsloth)
- ✅ **Tesla T4 optimized** with MoE layer CPU offloading
- ✅ **OpenAI-compatible API** via llama-server
- ✅ **Complete Kubernetes manifests** for all resources
- ✅ **Automatic model download** from Unsloth's GLM-4.6-GGUF repository
- ✅ **Fixed chat templates** (--jinja flag required for GLM-4.6)
- ✅ **Detailed deployment guides** and configuration docs
- ✅ **Network policies and security** best practices
- ✅ **Production-ready** with health checks and monitoring

## About GLM-4.6

**GLM-4.6** is Z.ai's latest reasoning model achieving SOTA performance on coding and agent benchmarks while offering improved conversational chats.

- **Full model:** 355B parameters, requires 400GB disk space
- **Unsloth Dynamic 2-bit GGUF:** 135GB (-75% size reduction)
- **Maximum context:** 200K tokens (start with 16K for Tesla T4)
- **Official settings:** temperature=1.0, top_p=0.95, top_k=40

**Important:** You **MUST** use `--jinja` flag for GLM-4.6 - Unsloth has fixed chat template issues that cause problems with non-Unsloth GGUFs.

## Why llama.cpp + GGUF?

| Feature | llama.cpp + GGUF | vLLM |
|---------|------------------|------|
| **Model Size** | 135GB (2.7-bit quant) | 400GB+ (full precision) |
| **VRAM Required** | ~24GB (with MoE offloading) | 80GB+ |
| **Tesla T4 Compatible** | ✅ Yes | ❌ Needs multiple GPUs |
| **Quantization** | Multiple options (1-5 bit) | Limited |
| **Setup Complexity** | Moderate | Simple |
| **Performance** | 3-5 tokens/s (T4 + RAM) | 10-20 tokens/s (A100) |

**Perfect for:** Cost-effective inference on Tesla T4, coding/agent tasks, and edge deployments.

## Quick Start

### Prerequisites

- **OpenShift/ARO cluster** 4.x with GPU-enabled nodes (Tesla T4 or better)
- **NVIDIA GPU Operator** installed
- **200GB+ storage** available (for model cache)
- **Hugging Face token** (get from: https://huggingface.co/settings/tokens)
- **`oc` CLI** installed and configured

### 5-Minute Deployment

```bash
# 1. Login to your cluster
oc login --server=https://api.your-cluster.com:6443 --token=YOUR_TOKEN

# 2. Navigate to deployment directory
cd openshift-glm46-llamacpp

# 3. Create namespace and storage
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-pvc.yaml

# 4. Create configuration
oc apply -f manifests/03-configmap.yaml

# 5. Create secret with your HuggingFace token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=your_token_here \
  -n llm-models-glm46

# 6. Deploy the service
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
oc apply -f manifests/08-networkpolicy.yaml

# 7. Get the API URL
oc get route glm46-llamacpp -n llm-models-glm46 -o jsonpath='{.spec.host}'
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
│  │  glm46-llamacpp │                                          │
│  └──────┬──────────┘                                          │
│         │                                                      │
│  ┌──────▼──────────────────────────────────────────────────┐ │
│  │              Pod: glm46-llamacpp                         │ │
│  ├──────────────────────────────────────────────────────────┤ │
│  │  Init Containers:                                        │ │
│  │  1. build-llamacpp (builds llama.cpp with CUDA)         │ │
│  │  2. model-downloader (downloads GGUF from Unsloth)      │ │
│  │                                                          │ │
│  │  Main Container:                                         │ │
│  │  └─ llama-server (OpenAI-compatible API)                │ │
│  │     • MoE layers offloaded to CPU                       │ │
│  │     • Non-MoE layers on GPU                             │ │
│  │     • --jinja for fixed chat templates                  │ │
│  │                                                          │ │
│  │  Resources:                                              │ │
│  │  • GPU: 1x NVIDIA Tesla T4 (16GB)                       │ │
│  │  • RAM: 64-128 GB (for MoE offloading)                  │ │
│  │  • CPU: 8-16 cores                                       │ │
│  │                                                          │ │
│  │  Volumes:                                                │ │
│  │  • PVC: glm46-gguf-cache (200GB) - GGUF models         │ │
│  │  • EmptyDir: llamacpp-bin - llama.cpp binaries         │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Model Options

Choose your quantization level in `03-configmap.yaml`:

| Quantization | Bits | Size | VRAM (w/ offload) | Quality | Speed |
|--------------|------|------|-------------------|---------|-------|
| **UD-TQ1_0** | 1.66 | 84GB | ~16GB | Good | Fastest |
| **UD-IQ1_S** | 1.78 | 96GB | ~18GB | Better | Fast |
| **UD-Q2_K_XL** ⭐ | 2.71 | 135GB | ~24GB | Best | Medium |
| **UD-Q4_K_XL** | 4.5 | 204GB | ~32GB | Excellent | Slower |

⭐ **Recommended:** `UD-Q2_K_XL` for best balance of quality and size

**Note:** All Unsloth uploads use Dynamic 2.0 for SOTA 5-shot MMLU and Aider performance.

## Resource Requirements

### Minimum Configuration (Tesla T4)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | 1x Tesla T4 (16GB) | 1x A10/A10G (24GB) |
| **Memory** | 64 GB | 128 GB |
| **CPU** | 8 cores | 16 cores |
| **Storage** | 150 GB | 250 GB SSD |
| **Network** | 100 Mbps | 1 Gbps |

### Performance Expectations

**Tesla T4 (16GB) with MoE offloading (UD-Q2_K_XL):**
- Context length: 16K tokens
- Speed: 3-5 tokens/second
- Concurrent requests: 1-2
- Memory usage: ~64GB RAM + 16GB VRAM

**A10/A10G (24GB) with partial offloading (UD-Q2_K_XL):**
- Context length: 32K tokens
- Speed: 5-8 tokens/second
- Concurrent requests: 2-4
- Memory usage: ~48GB RAM + 24GB VRAM

## API Usage

The deployment provides an OpenAI-compatible API:

### Test the API

```bash
# Get your route URL
ROUTE_URL=$(oc get route glm46-llamacpp -n llm-models-glm46 -o jsonpath='{.spec.host}')

# Health check
curl https://$ROUTE_URL/health

# List models
curl https://$ROUTE_URL/v1/models

# Chat completion
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.6",
    "messages": [
      {"role": "user", "content": "Write a Python function to calculate fibonacci numbers."}
    ],
    "max_tokens": 500,
    "temperature": 1.0,
    "top_p": 0.95,
    "top_k": 40
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

# Chat completion (coding task)
response = client.chat.completions.create(
    model="glm-4.6",
    messages=[
        {"role": "user", "content": "Explain how transformers work in deep learning."}
    ],
    temperature=1.0,
    top_p=0.95,
    top_k=40,
    max_tokens=1000
)

print(response.choices[0].message.content)
```

## Configuration

### Switching Quantization Levels

Edit `manifests/03-configmap.yaml`:

```yaml
# Smallest, fastest (84GB)
QUANT_TYPE: "UD-TQ1_0"

# Balanced, recommended (135GB)
QUANT_TYPE: "UD-Q2_K_XL"

# Higher quality (204GB)
QUANT_TYPE: "UD-Q4_K_XL"
```

### MoE Offloading Strategies

```yaml
# Maximum offloading - uses least VRAM (~16GB for T4)
MoE_OFFLOAD: ".ffn_.*_exps.=CPU"

# Moderate offloading (~24GB VRAM)
MoE_OFFLOAD: ".ffn_(up|down)_exps.=CPU"

# Minimal offloading (~32GB VRAM)
MoE_OFFLOAD: ".ffn_(up)_exps.=CPU"

# No offloading (requires 135GB+ VRAM for UD-Q2_K_XL!)
MoE_OFFLOAD: ""
```

### Adjusting Context Size

```yaml
# Small context (faster, less memory)
CTX_SIZE: "8192"

# Medium context (balanced)
CTX_SIZE: "16384"

# Large context (slower, more memory)
CTX_SIZE: "32768"

# Maximum for GLM-4.6 (requires significant RAM)
CTX_SIZE: "200000"
```

## Monitoring

### Check Deployment Status

```bash
# Pod status
oc get pods -n llm-models-glm46 -l app=glm-4.6-llamacpp

# Watch init containers progress
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c build-llamacpp
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c model-downloader

# Main server logs
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c llama-server

# Resource usage
oc adm top pod -n llm-models-glm46
```

### GPU Monitoring

```bash
# Get GPU node
GPU_NODE=$(oc get pod -n llm-models-glm46 -l app=glm-4.6-llamacpp \
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
oc logs -n llm-models-glm46 -l app=glm-4.6-llamacpp -c build-llamacpp

# Common fix: Increase memory limits in deployment
# Edit 05-deployment.yaml, increase build-llamacpp memory to 16Gi
```

#### 2. Model Download Slow/Timeout

**Symptom:** `model-downloader` takes too long or times out

**Solution:**
```bash
# The download can take 30-90 minutes for UD-Q2_K_XL (135GB)
# Check progress:
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c model-downloader

# If timeout, increase init container timeout or download manually
```

#### 3. Out of Memory

**Symptom:** Pod killed due to OOM

**Solutions:**
1. Use smaller quantization (`UD-TQ1_0` instead of `UD-Q2_K_XL`)
2. Increase memory limits in deployment
3. Ensure MoE offloading is enabled
4. Reduce context size (`CTX_SIZE: "8192"`)

#### 4. Chat Template Issues

**Symptom:** Responses are broken or second prompt doesn't work

**Solution:**
```bash
# Ensure --jinja flag is present in deployment (it is by default)
# This uses Unsloth's fixed chat templates for GLM-4.6
# Verify in deployment.yaml that llama-server has --jinja flag
```

#### 5. Slow Inference

**Symptom:** Less than 3 tokens/second on T4

**Solutions:**
1. Reduce MoE offloading (but needs more VRAM)
2. Increase CPU cores allocation
3. Use faster storage (SSD instead of HDD)
4. Reduce context size
5. Use smaller quantization

## Performance Tuning

### For Tesla T4 (16GB VRAM)

```yaml
# ConfigMap optimizations
QUANT_TYPE: "UD-TQ1_0"               # Smallest quant
CTX_SIZE: "8192"                      # Smaller context
N_GPU_LAYERS: "99"                    # Offload all non-MoE
MoE_OFFLOAD: ".ffn_.*_exps.=CPU"     # Full MoE offload
THREADS: "-1"                         # Use all CPUs
```

### For A10/A10G (24GB VRAM)

```yaml
# ConfigMap optimizations
QUANT_TYPE: "UD-Q2_K_XL"             # Balanced quant
CTX_SIZE: "32768"                     # Larger context
N_GPU_LAYERS: "99"                    # Offload all non-MoE
MoE_OFFLOAD: ".ffn_(up|down)_exps.=CPU"  # Partial MoE offload
```

## Cleanup

### Remove Everything

```bash
# Delete all resources
oc delete -f manifests/

# Or delete namespace (removes everything)
oc delete namespace llm-models-glm46
```

### Keep Model Cache

To avoid re-downloading:

```bash
# Delete everything except PVC
oc delete deployment,service,route,configmap,secret,networkpolicy \
  -n llm-models-glm46 --all

# Later, redeploy without re-downloading
oc apply -f manifests/03-configmap.yaml
oc create secret generic huggingface-token --from-literal=HF_TOKEN=xxx -n llm-models-glm46
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
```

## Credits & Resources

**Technologies:**
- [llama.cpp](https://github.com/ggml-org/llama.cpp) - Efficient LLM inference
- [Unsloth GGUF Models](https://huggingface.co/unsloth/GLM-4.6-GGUF) - Optimized quantizations
- [GLM-4.6](https://huggingface.co/THUDM/glm-4-9b) - Z.ai's reasoning model
- [Azure Red Hat OpenShift](https://azure.microsoft.com/en-us/products/openshift) - Enterprise Kubernetes

**Documentation:**
- [Unsloth GLM-4.6 Guide](https://docs.unsloth.ai/models/glm-4.6-how-to-run-locally)
- [llama.cpp docs](https://github.com/ggml-org/llama.cpp/tree/master/docs)
- [OpenShift GPU docs](https://docs.openshift.com/container-platform/latest/architecture/nvidia-gpu-architecture-overview.html)

---

**Ready to deploy?** Follow the Quick Start guide above!
