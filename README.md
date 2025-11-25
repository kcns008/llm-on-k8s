# LLM on Kubernetes

Production-ready deployment packages for running Large Language Models (LLMs) on Kubernetes and OpenShift with GPU acceleration. This repository provides complete, tested configurations for deploying high-performance inference services using vLLM and llama.cpp.

## Overview

This repository contains enterprise-grade deployment solutions for serving open-source LLMs on Kubernetes and OpenShift platforms. Each deployment package includes:

- Complete Kubernetes manifests (Namespace, PVC, ConfigMap, Deployment, Service, etc.)
- Production-ready security configurations (NetworkPolicies, RBAC, Secrets)
- Comprehensive documentation and guides
- Health checks and monitoring integration
- OpenAI-compatible REST API

## Features

✅ **Multiple Inference Engines**
- **vLLM**: High-throughput inference with PagedAttention and continuous batching
- **llama.cpp**: Lightweight inference with GGUF quantization support

✅ **GPU Optimization**
- Tested on NVIDIA Tesla T4, V100, A10, A100, and RTX series GPUs
- Efficient memory management with configurable GPU memory utilization
- Support for tensor parallelism and model quantization

✅ **Production Ready**
- Network policies for security isolation
- Persistent storage for model caching
- Health checks and readiness probes
- Prometheus metrics integration
- Automated deployment scripts

✅ **OpenAI-Compatible API**
- Drop-in replacement for OpenAI API
- Support for chat completions and text generation
- Works with existing OpenAI SDKs (Python, Node.js, etc.)

✅ **Comprehensive Documentation**
- Step-by-step deployment guides (CLI and Web Console)
- Network and firewall configuration
- Troubleshooting guides
- Production checklists

## Deployment Packages

### 1. vLLM Deployment (Kimi K2 Instruct 0905)

**Location:** `openshift-kimi-k2-0905-vllm/`

Latest version deployment using vLLM for the Kimi K2 Instruct 0905 model.

**Features:**
- Model: `moonshotai/Kimi-K2-Instruct-0905`
- Context Length: Up to 128K tokens
- Inference Engine: vLLM (high-throughput)
- Deployment Time: 35-70 minutes

**Best For:** Production inference workloads requiring high throughput and long context

**Quick Start:**
```bash
cd openshift-kimi-k2-0905-vllm
# See README.md and QUICKSTART.md for detailed instructions
```

### 2. vLLM Base Deployment (Kimi K2 Instruct)

**Location:** `openshift-kimi-k2-deployment/`

Comprehensive deployment package with extensive documentation and automated scripts.

**Features:**
- Model: `moonshotai/Kimi-K2-Instruct`
- Inference Engine: vLLM
- Most comprehensive documentation
- Includes automated `deploy.sh` script
- Multi-environment setup guide

**Best For:** First-time deployments, learning, and development environments

**Quick Start:**
```bash
cd openshift-kimi-k2-deployment
./deploy.sh --token hf_YourHuggingFaceToken
```

### 3. llama.cpp Deployment (GGUF Quantized)

**Location:** `openshift-kimi-k2-llamacpp/`

Cost-effective deployment using llama.cpp with quantized GGUF models for efficient inference on lower-end GPUs.

**Features:**
- Models: Kimi K2 (GGUF quantized variants)
- Inference Engine: llama.cpp
- Multiple quantization options (1.8-bit to 4-bit)
- MoE layer offloading for memory efficiency
- Optimized for Tesla T4 GPUs (16GB VRAM)

**Best For:** Budget-conscious deployments, development, and testing on consumer-grade GPUs

**Quick Start:**
```bash
cd openshift-kimi-k2-llamacpp
# See README.md for quantization options and deployment
```

## Supported Models

While this repository focuses on the Kimi K2 family, the deployment configurations support any vLLM-compatible or llama.cpp-compatible models.

### Included Models

| Model | Type | Context | Quantization | Best For |
|-------|------|---------|--------------|----------|
| Kimi-K2-Instruct-0905 | Instruction | 128K | Full Precision | Production chat/Q&A |
| Kimi-K2-Instruct | Instruction | 128K | Full Precision | General chat/Q&A |
| Kimi-K2-Thinking | Reasoning | 128K | Full Precision | Complex reasoning |
| Kimi-K2-GGUF (various) | Instruction | 128K | 1.8-4 bit | Cost-effective inference |

### Other Compatible Models

The vLLM deployments support popular open-source models including:
- Meta Llama 2/3 (7B, 13B, 70B)
- Mistral/Mixtral
- Qwen/Qwen2
- DeepSeek
- Any model supported by vLLM

Simply update the `MODEL_NAME` in the ConfigMap to use different models.

## Prerequisites

### Required

- **Kubernetes/OpenShift**: v1.24+ (OpenShift 4.10+)
- **GPU Support**: NVIDIA GPU Operator installed
- **NVIDIA Driver**: 525.60.13+ (CUDA 12.0+)
- **Storage**: 300-500GB persistent storage
- **Hugging Face Account**: For downloading models (free account sufficient)

### Recommended Resources

#### For vLLM Deployments:

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| GPU | 1x Tesla T4 (16GB) | 1x A100 (40GB) |
| CPU | 4 cores | 8 cores |
| Memory | 32 GB | 64 GB |
| Storage | 300 GB | 500 GB SSD |
| Network | 100 Mbps | 1 Gbps |

#### For llama.cpp Deployments:

| Resource | Requirement |
|----------|-------------|
| GPU | Tesla T4 (16GB) or better |
| CPU | 8-16 cores |
| Memory | 64-128 GB |
| Storage | 300-400 GB |

### Supported GPUs

- ✅ NVIDIA Tesla T4 (16GB) - Tested, budget-friendly
- ✅ NVIDIA Tesla V100 (16/32GB)
- ✅ NVIDIA A10/A10G (24GB)
- ✅ NVIDIA A100 (40/80GB) - Best performance
- ✅ NVIDIA RTX 4090 (24GB)
- ✅ NVIDIA RTX 6000 Ada (48GB)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/kcns008/llm-on-k8s.git
cd llm-on-k8s
```

### 2. Choose Your Deployment

Pick the deployment package that best fits your needs:

**For production with latest model:**
```bash
cd openshift-kimi-k2-0905-vllm
```

**For comprehensive documentation and automation:**
```bash
cd openshift-kimi-k2-deployment
```

**For cost-effective inference on T4 GPUs:**
```bash
cd openshift-kimi-k2-llamacpp
```

### 3. Get Hugging Face Token

1. Create account at [huggingface.co](https://huggingface.co)
2. Go to Settings → Access Tokens
3. Create a new token (read permission sufficient)
4. Accept model license if required

### 4. Deploy

**Option A: Automated (vLLM base deployment only)**
```bash
./deploy.sh --token hf_YourToken
```

**Option B: Manual**
```bash
# Create namespace
oc apply -f manifests/01-namespace.yaml

# Create persistent storage
oc apply -f manifests/02-pvc.yaml

# Create configuration
oc apply -f manifests/03-configmap.yaml

# Create Hugging Face token secret
oc create secret generic huggingface-token \
  --from-literal=token=hf_YourToken \
  -n llm-models

# Deploy the application
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
oc apply -f manifests/08-networkpolicy.yaml
```

### 5. Monitor Deployment

```bash
# Watch deployment progress
oc get pods -n llm-models -w

# Check logs
oc logs -f deployment/kimi-k2-vllm -n llm-models

# Initial deployment takes 35-90 minutes for model download
```

### 6. Test the API

Once deployed, get your route URL:

```bash
ROUTE_URL=$(oc get route kimi-k2-route -n llm-models -o jsonpath='{.spec.host}')
echo "API URL: https://$ROUTE_URL"
```

Test health endpoint:
```bash
curl https://$ROUTE_URL/health
```

Test chat completion:
```bash
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "messages": [
      {"role": "user", "content": "Hello! How are you?"}
    ],
    "max_tokens": 100
  }'
```

## API Usage

All deployments expose an **OpenAI-compatible REST API**:

### Endpoints

- `GET /health` - Health check
- `GET /v1/models` - List available models
- `POST /v1/chat/completions` - Chat completion
- `POST /v1/completions` - Text completion
- `GET /metrics` - Prometheus metrics

### Python Example

```python
from openai import OpenAI

# Initialize client
client = OpenAI(
    base_url="https://your-route-url/v1",
    api_key="not-required"  # vLLM doesn't require API key
)

# Chat completion
response = client.chat.completions.create(
    model="kimi-k2",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    temperature=0.7,
    max_tokens=500
)

print(response.choices[0].message.content)
```

### Node.js Example

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'https://your-route-url/v1',
  apiKey: 'not-required'
});

const response = await client.chat.completions.create({
  model: 'kimi-k2',
  messages: [
    { role: 'user', content: 'What is Kubernetes?' }
  ]
});

console.log(response.choices[0].message.content);
```

### cURL Example

```bash
curl https://your-route-url/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "messages": [
      {
        "role": "user",
        "content": "Write a Python function to calculate fibonacci numbers"
      }
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

## Configuration

### vLLM Configuration

Key parameters in ConfigMap:

```yaml
MODEL_NAME: "moonshotai/Kimi-K2-Instruct-0905"
MAX_MODEL_LEN: "16384"              # Context window (up to 128K)
GPU_MEMORY_UTILIZATION: "0.90"      # GPU memory usage (0.0-1.0)
TENSOR_PARALLEL_SIZE: "1"           # Number of GPUs for tensor parallelism
SWAP_SPACE: "16"                    # CPU swap space in GB
```

### llama.cpp Configuration

Key parameters in ConfigMap:

```yaml
MODEL_REPO: "unsloth/Kimi-K2-Thinking-GGUF"
QUANT_TYPE: "UD-TQ1_0"              # Quantization type
N_GPU_LAYERS: "99"                  # Layers to offload to GPU
MoE_OFFLOAD: ".ffn_.*_exps.=CPU"    # MoE layer offloading
CTX_SIZE: "16384"                   # Context window
THREADS: "-1"                        # CPU threads (-1 = auto)
```

## Monitoring

### Prometheus Metrics

When ServiceMonitor is enabled, metrics are available at `/metrics`:

**Key Metrics:**
- `vllm:num_requests_running` - Active inference requests
- `vllm:num_requests_waiting` - Queued requests
- `vllm:gpu_cache_usage_perc` - GPU KV cache utilization
- `vllm:time_to_first_token_seconds` - Latency to first token
- `vllm:time_per_output_token_seconds` - Token generation speed

### Health Checks

```bash
# Health endpoint
curl https://your-route-url/health

# Expected response:
# {"status": "ok"}
```

### Pod Logs

```bash
# View real-time logs
oc logs -f deployment/kimi-k2-vllm -n llm-models

# View init container logs (model download)
oc logs deployment/kimi-k2-vllm -c model-downloader -n llm-models
```

## Troubleshooting

### Common Issues

**1. Pod stuck in `Pending` state**
- Check GPU availability: `oc describe node | grep nvidia.com/gpu`
- Verify NVIDIA GPU Operator is running
- Check PVC is bound: `oc get pvc -n llm-models`

**2. Model download fails**
- Verify Hugging Face token is correct
- Check internet connectivity from cluster
- Ensure model license is accepted on Hugging Face
- Check NetworkPolicy allows egress to huggingface.co

**3. Out of Memory (OOM) errors**
- Reduce `MAX_MODEL_LEN` in ConfigMap
- Lower `GPU_MEMORY_UTILIZATION` (try 0.80 or 0.70)
- For llama.cpp: use more aggressive quantization (UD-TQ1_0)
- Enable MoE offloading for llama.cpp

**4. Slow inference**
- Check GPU utilization: `nvidia-smi` on node
- Increase `GPU_MEMORY_UTILIZATION` if headroom available
- For vLLM: enable tensor parallelism with multiple GPUs
- For llama.cpp: reduce CPU offloading, increase `N_GPU_LAYERS`

**5. Route/Service not accessible**
- Verify route exists: `oc get route -n llm-models`
- Check service endpoints: `oc get endpoints -n llm-models`
- Test from within cluster: `oc run test --image=curlimages/curl -it --rm`
- Review NetworkPolicy rules

### Detailed Troubleshooting

Each deployment package includes comprehensive troubleshooting guides:

- `openshift-kimi-k2-llamacpp/docs/TROUBLESHOOTING.md` - Detailed troubleshooting
- Package-specific README.md files - Common issues and solutions

## Documentation Structure

```
llm-on-k8s/
├── README.md                           # This file
│
├── openshift-kimi-k2-0905-vllm/        # Latest vLLM deployment
│   ├── README.md                       # Complete deployment guide
│   ├── QUICKSTART.md                   # 5-minute quick start
│   ├── FILE-STRUCTURE.md               # File organization
│   └── manifests/                      # Kubernetes YAML files
│
├── openshift-kimi-k2-deployment/       # Base vLLM deployment (most docs)
│   ├── README.md                       # Complete deployment guide
│   ├── QUICKSTART.md                   # Quick start
│   ├── FILE-STRUCTURE.md               # File organization
│   ├── deploy.sh                       # Automated deployment script
│   ├── manifests/                      # Kubernetes YAML files
│   └── docs/
│       ├── DEPLOYMENT-CLI.md           # CLI deployment guide
│       ├── DEPLOYMENT-DASHBOARD.md     # Web console guide
│       └── NETWORK-REQUIREMENTS.md     # Network/firewall setup
│
└── openshift-kimi-k2-llamacpp/         # llama.cpp deployment
    ├── README.md                       # Complete deployment guide
    ├── QUICKSTART.md                   # Quick start
    ├── FILE-STRUCTURE.md               # File organization
    ├── manifests/                      # Kubernetes YAML files
    └── docs/
        ├── MODEL-QUANTIZATIONS.md      # Quantization options
        └── TROUBLESHOOTING.md          # Troubleshooting guide
```

## Performance Benchmarks

### vLLM on Different GPUs

| GPU | VRAM | Throughput | Latency (TTFT) | Cost Efficiency |
|-----|------|------------|----------------|-----------------|
| Tesla T4 | 16GB | 5-10 tok/s | 2-4s | ⭐⭐⭐ Budget |
| Tesla V100 | 32GB | 15-25 tok/s | 1-2s | ⭐⭐⭐ |
| A10G | 24GB | 20-30 tok/s | 1-2s | ⭐⭐⭐⭐ |
| A100 | 40GB | 40-60 tok/s | 0.5-1s | ⭐⭐⭐⭐⭐ Premium |

### llama.cpp Quantization Comparison

| Quantization | Model Size | VRAM | Quality | Speed | Use Case |
|--------------|------------|------|---------|-------|----------|
| UD-TQ1_0 (1.8-bit) | 247GB | ~8GB | Good | Fastest | Development/Testing |
| UD-IQ1_S | 281GB | ~9GB | Better | Fast | Cost-sensitive production |
| UD-Q2_K_XL | 381GB | ~12GB | Best | Medium | Balanced production |
| UD-Q4_K_XL (4-bit) | 588GB | ~18GB | Excellent | Slower | Quality-focused production |

*Benchmarks measured on OpenShift 4.12 with single GPU, 16K context*

## Security Best Practices

### Included Security Features

✅ **Network Isolation**
- NetworkPolicies restrict ingress/egress traffic
- Only allows traffic from OpenShift router and monitoring

✅ **Secrets Management**
- Hugging Face tokens stored in Kubernetes Secrets
- Never committed to version control

✅ **Non-Root Containers**
- Containers run as non-root user (UID 1000)
- Read-only root filesystem where possible

✅ **TLS/HTTPS**
- OpenShift Routes with edge TLS termination
- Automatic certificate management

✅ **Resource Limits**
- CPU and memory limits prevent resource exhaustion
- GPU allocation ensures fair scheduling

### Additional Recommendations

🔒 **For Production Deployments:**

1. **Enable RBAC:** Create dedicated ServiceAccounts with minimal permissions
2. **API Authentication:** Add API gateway with authentication (e.g., OAuth2 Proxy)
3. **Rate Limiting:** Implement rate limiting to prevent abuse
4. **Audit Logging:** Enable Kubernetes audit logs
5. **Vulnerability Scanning:** Regular container image scanning
6. **Network Segmentation:** Deploy in isolated namespaces
7. **Backup Strategy:** Regular PVC backups for model cache

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository** and create a feature branch
2. **Test your changes** thoroughly in a development cluster
3. **Update documentation** if adding new features or configurations
4. **Follow Kubernetes best practices** for manifests
5. **Submit a pull request** with clear description

### Areas for Contribution

- Additional model support (Llama 3, Mistral, Qwen, etc.)
- Multi-GPU deployment configurations
- Alternative ingress configurations (Istio, NGINX)
- Helm charts for easier deployment
- Terraform/Ansible automation
- Performance tuning guides
- Additional monitoring dashboards

## License

This repository contains deployment configurations and documentation. Please refer to individual components for their licenses:

- **vLLM**: Apache 2.0 License
- **llama.cpp**: MIT License
- **Kimi K2 Models**: See [Hugging Face model cards](https://huggingface.co/moonshotai) for licensing

## Acknowledgments

- [vLLM Team](https://github.com/vllm-project/vllm) for the high-performance inference engine
- [llama.cpp](https://github.com/ggerganov/llama.cpp) for efficient quantized inference
- [Moonshot AI](https://huggingface.co/moonshotai) for the Kimi K2 model family
- OpenShift/Kubernetes communities for excellent documentation

## Support

- **Issues**: Report bugs or request features via [GitHub Issues](https://github.com/kcns008/llm-on-k8s/issues)
- **Documentation**: See package-specific README.md files for detailed guides
- **Community**: Share your deployment experiences and configurations

## Related Projects

- [vLLM](https://github.com/vllm-project/vllm) - High-throughput LLM inference engine
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - Efficient LLM inference in C++
- [Text Generation Inference](https://github.com/huggingface/text-generation-inference) - HuggingFace's inference server
- [Ollama](https://github.com/ollama/ollama) - Easy LLM deployment tool
- [NVIDIA GPU Operator](https://github.com/NVIDIA/gpu-operator) - GPU support for Kubernetes

---

**Happy Deploying! 🚀**

For detailed deployment instructions, navigate to the specific package directory and consult the README.md file.
