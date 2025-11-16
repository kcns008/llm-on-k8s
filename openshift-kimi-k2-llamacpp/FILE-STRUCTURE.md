# File Structure

Complete overview of the deployment package structure and file purposes.

## Directory Tree

```
openshift-kimi-k2-llamacpp/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # 5-minute deployment guide
├── FILE-STRUCTURE.md              # This file
│
├── manifests/                     # Kubernetes resource definitions
│   ├── 01-namespace.yaml          # Namespace: llm-models-llamacpp
│   ├── 02-pvc.yaml                # 400GB storage for GGUF models
│   ├── 03-configmap.yaml          # llama.cpp configuration
│   ├── 04-secret.yaml             # HuggingFace token (template)
│   ├── 05-deployment.yaml         # Main deployment with init containers
│   ├── 06-service.yaml            # ClusterIP service
│   ├── 07-route.yaml              # OpenShift route (HTTPS)
│   └── 08-networkpolicy.yaml      # Network security policies
│
├── docs/                          # Detailed documentation
│   ├── MODEL-QUANTIZATIONS.md     # Guide to choosing GGUF quants
│   └── TROUBLESHOOTING.md         # Common issues and solutions
│
└── scripts/                       # Helper scripts
    └── deploy.sh                  # One-command deployment script
```

## File Descriptions

### Root Files

#### README.md
- **Purpose:** Main documentation and project overview
- **Audience:** Everyone - start here
- **Contents:**
  - Architecture overview
  - Resource requirements
  - API usage examples
  - Configuration guide
  - Comparison with vLLM

#### QUICKSTART.md
- **Purpose:** Fastest path to deployment
- **Audience:** Users who want to deploy quickly
- **Contents:**
  - Prerequisites checklist
  - Step-by-step deployment (8 steps)
  - Monitoring commands
  - Testing examples
  - Quick troubleshooting

#### FILE-STRUCTURE.md
- **Purpose:** Explain repository organization
- **Audience:** Developers, contributors
- **Contents:**
  - Directory tree
  - File-by-file descriptions
  - Usage notes

---

## Manifests Directory

All Kubernetes/OpenShift resource definitions. Apply in numerical order.

### 01-namespace.yaml

**Purpose:** Creates isolated namespace for deployment

**Resource:** Namespace `llm-models-llamacpp`

**Usage:**
```bash
oc apply -f manifests/01-namespace.yaml
```

**Key Features:**
- Labels for organization
- Annotations for documentation

**When to modify:**
- Change namespace name (update all other manifests too)

---

### 02-pvc.yaml

**Purpose:** Persistent storage for GGUF model files

**Resource:** PersistentVolumeClaim `kimi-k2-gguf-cache`

**Default size:** 400Gi

**Usage:**
```bash
oc apply -f manifests/02-pvc.yaml
```

**Key Features:**
- ReadWriteOnce access mode
- Filesystem volume mode
- Optional storage class specification

**When to modify:**
- Adjust size based on quantization choice:
  - UD-TQ1_0: 300Gi minimum
  - UD-Q2_K_XL: 450Gi minimum
  - UD-Q4_K_XL: 650Gi minimum
- Specify storage class for your cluster
- Change to SSD-backed storage for better performance

---

### 03-configmap.yaml

**Purpose:** Configuration parameters for llama.cpp server

**Resource:** ConfigMap `kimi-k2-llamacpp-config`

**Usage:**
```bash
oc apply -f manifests/03-configmap.yaml
```

**Key Parameters:**

| Parameter | Default | Purpose |
|-----------|---------|---------|
| MODEL_REPO | unsloth/Kimi-K2-Thinking-GGUF | Which model to download |
| QUANT_TYPE | UD-TQ1_0 | Quantization level |
| TEMPERATURE | 1.0 | Sampling temperature |
| MIN_P | 0.01 | Minimum probability threshold |
| CTX_SIZE | 16384 | Context window size |
| N_GPU_LAYERS | 99 | Layers to offload to GPU |
| MoE_OFFLOAD | .ffn_.*_exps.=CPU | MoE offloading pattern |
| THREADS | -1 | CPU threads (auto) |

**When to modify:**
- Switch between Thinking/Instruct model
- Change quantization level
- Tune performance parameters
- Adjust for different GPU types

**After modifying:**
```bash
oc rollout restart deployment kimi-k2-llamacpp -n llm-models-llamacpp
```

---

### 04-secret.yaml

**Purpose:** Template for HuggingFace authentication token

**Resource:** Secret `huggingface-token`

**⚠️ WARNING:** This is a TEMPLATE - do not apply directly

**Usage:**
```bash
# Create secret with actual token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_your_actual_token \
  -n llm-models-llamacpp
```

**Security notes:**
- Never commit real tokens to git
- Rotate tokens regularly
- Use read-only tokens when possible

---

### 05-deployment.yaml

**Purpose:** Main application deployment with llama.cpp server

**Resource:** Deployment `kimi-k2-llamacpp`

**Replicas:** 1 (GPU workloads don't auto-scale easily)

**Strategy:** Recreate (ensures clean GPU release)

**Containers:**

#### Init Container: build-llamacpp
- **Image:** nvidia/cuda:12.1.0-devel-ubuntu22.04
- **Purpose:** Build llama.cpp from source with CUDA support
- **Runtime:** 10-15 minutes
- **Output:** Binaries in `/llamacpp` volume
- **Resources:** 2-4 CPU, 4-8Gi memory

#### Init Container: model-downloader
- **Image:** python:3.11-slim
- **Purpose:** Download GGUF model from HuggingFace
- **Runtime:** 30-90 minutes (depends on quantization)
- **Output:** Model files in `/model-cache` PVC
- **Resources:** 2-4 CPU, 4-8Gi memory

#### Main Container: llama-server
- **Image:** nvidia/cuda:12.1.0-runtime-ubuntu22.04
- **Purpose:** Run llama-server with OpenAI-compatible API
- **Port:** 8001
- **Resources:**
  - GPU: 1x NVIDIA Tesla T4
  - Memory: 64-128Gi (for MoE offloading)
  - CPU: 8-16 cores

**Health Checks:**
- Liveness probe: GET /health every 30s
- Readiness probe: GET /health every 10s
- Startup probe: GET /health (up to 5 min)

**Volumes:**
- model-cache (PVC): Read-only, contains GGUF files
- llamacpp-bin (emptyDir): Contains llama.cpp binaries

**When to modify:**
- Adjust resource limits for your nodes
- Change image versions
- Tune health check timings
- Add tolerations/node selectors for your GPU nodes

---

### 06-service.yaml

**Purpose:** Internal service for pod access

**Resource:** Service `kimi-k2-llamacpp`

**Type:** ClusterIP

**Port:** 8001 → 8001

**Usage:**
```bash
oc apply -f manifests/06-service.yaml
```

**Access from within cluster:**
```
http://kimi-k2-llamacpp.llm-models-llamacpp.svc.cluster.local:8001
```

**When to modify:**
- Change service type (LoadBalancer, NodePort)
- Add session affinity

---

### 07-route.yaml

**Purpose:** External HTTPS access via OpenShift router

**Resource:** Route `kimi-k2-llamacpp`

**TLS:** Edge termination (router handles SSL)

**Usage:**
```bash
oc apply -f manifests/07-route.yaml

# Get URL
oc get route kimi-k2-llamacpp -n llm-models-llamacpp \
  -o jsonpath='{.spec.host}'
```

**Annotations:**
- 5-minute timeout for long-running requests
- Round-robin load balancing

**When to modify:**
- Specify custom hostname
- Adjust timeout for longer inference
- Add rate limiting annotations

---

### 08-networkpolicy.yaml

**Purpose:** Network security and access control

**Resources:**
- NetworkPolicy: allow-from-router
- NetworkPolicy: allow-monitoring

**Rules:**
- ✅ Allow ingress from OpenShift router
- ✅ Allow ingress from monitoring namespace
- ✅ Allow egress to DNS
- ✅ Allow egress for HTTPS (model download)
- ❌ Deny all other traffic

**Usage:**
```bash
oc apply -f manifests/08-networkpolicy.yaml
```

**When to modify:**
- Allow access from specific namespaces
- Add egress rules for external services
- Adjust for service mesh

**Troubleshooting:**
If network policies block legitimate traffic:
```bash
# Temporarily remove to test
oc delete networkpolicy -n llm-models-llamacpp --all
```

---

## Documentation Directory

### docs/MODEL-QUANTIZATIONS.md

**Purpose:** Comprehensive guide to GGUF quantizations

**Contents:**
- What is quantization
- All available quantizations (TQ1_0 to Q5_K_XL)
- Comparison tables
- Decision tree for choosing quantization
- Benchmarks and quality metrics
- Storage planning

**Audience:** Users deciding which quantization to use

---

### docs/TROUBLESHOOTING.md

**Purpose:** Solutions to common problems

**Contents:**
- Deployment issues
- Init container failures
- Runtime crashes
- Performance problems
- Network connectivity
- GPU detection
- Debugging commands

**Audience:** Anyone encountering issues

---

## Scripts Directory

### scripts/deploy.sh

**Purpose:** Automated one-command deployment

**Usage:**
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**Features:**
- Prompts for HuggingFace token
- Validates prerequisites
- Applies manifests in correct order
- Monitors deployment progress
- Shows final API endpoint

**When to use:**
- First-time deployment
- Demo/testing scenarios
- CI/CD automation

---

## Usage Workflows

### Initial Deployment

```bash
1. cd openshift-kimi-k2-llamacpp
2. oc login (to your cluster)
3. Review/edit manifests/03-configmap.yaml (optional)
4. oc apply -f manifests/01-namespace.yaml
5. oc apply -f manifests/02-pvc.yaml
6. oc apply -f manifests/03-configmap.yaml
7. oc create secret generic huggingface-token --from-literal=HF_TOKEN=xxx -n llm-models-llamacpp
8. oc apply -f manifests/05-deployment.yaml
9. oc apply -f manifests/06-service.yaml
10. oc apply -f manifests/07-route.yaml
11. oc apply -f manifests/08-networkpolicy.yaml (optional)
```

### Configuration Changes

```bash
# Edit config
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp

# Restart to apply
oc rollout restart deployment kimi-k2-llamacpp -n llm-models-llamacpp
```

### Switching Models

```bash
# 1. Edit ConfigMap
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
# Change MODEL_REPO to: unsloth/Kimi-K2-Instruct-GGUF
# Change TEMPERATURE to: 0.6

# 2. Delete pod to trigger re-download
oc delete pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# 3. Monitor download
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader
```

### Cleanup

```bash
# Delete everything
oc delete -f manifests/

# Or just delete namespace
oc delete namespace llm-models-llamacpp
```

---

## Customization Points

### For Different Clusters

| File | What to Change |
|------|----------------|
| 02-pvc.yaml | storage class name |
| 05-deployment.yaml | node selectors, tolerations |
| 05-deployment.yaml | image registry (if air-gapped) |
| 07-route.yaml | custom hostname |
| 08-networkpolicy.yaml | namespace labels |

### For Different Models

| File | What to Change |
|------|----------------|
| 03-configmap.yaml | MODEL_REPO, QUANT_TYPE, TEMPERATURE |
| 02-pvc.yaml | storage size |
| 05-deployment.yaml | memory limits (for larger quants) |

### For Different GPUs

| GPU Type | Changes Needed |
|----------|----------------|
| **A10/A10G** | Increase VRAM expectations, reduce MoE offload |
| **V100** | Similar to A10 |
| **A100** | Can run without MoE offload, increase N_GPU_LAYERS |
| **Multi-GPU** | Not recommended with llama.cpp (use vLLM instead) |

---

## Version Control

**What to commit:**
- ✅ All manifests (but not with real tokens in 04-secret.yaml)
- ✅ Documentation
- ✅ Scripts

**What NOT to commit:**
- ❌ Real HuggingFace tokens
- ❌ Cluster-specific details (IPs, domains)
- ❌ Downloaded model files

**Gitignore recommendations:**
```gitignore
# Secrets
**/04-secret.yaml

# Local testing
*.local.yaml
test-*.yaml

# Downloaded models
*.gguf
model-cache/
```

---

**Questions?** See [Main README](README.md) or [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
