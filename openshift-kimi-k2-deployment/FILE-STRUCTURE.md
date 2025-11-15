# File Structure

## Overview

This deployment package contains everything needed to run Kimi K2 LLM on OpenShift.

```
openshift-kimi-k2-deployment/
├── README.md                          # Main documentation and overview
├── QUICKSTART.md                      # Quick start guide (5-minute setup)
├── FILE-STRUCTURE.md                  # This file
├── deploy.sh                          # Automated deployment script (executable)
│
├── manifests/                         # Kubernetes/OpenShift manifests
│   ├── 01-namespace.yaml              # Namespace: llm-models
│   ├── 02-pvc.yaml                    # Storage: 300GB model cache + 10GB shm
│   ├── 03-configmap.yaml              # Configuration: model settings, GPU tuning
│   ├── 04-secret.yaml                 # Secret template: HuggingFace token
│   ├── 05-deployment.yaml             # Deployment: vLLM server with GPU
│   ├── 06-service.yaml                # Service: Internal ClusterIP on port 8000
│   ├── 07-route.yaml                  # Route: External HTTPS access
│   ├── 08-networkpolicy.yaml          # NetworkPolicy: Security rules
│   └── 09-servicemonitor.yaml         # ServiceMonitor: Prometheus metrics
│
└── docs/                              # Detailed documentation
    ├── DEPLOYMENT-CLI.md              # CLI deployment guide (oc commands)
    ├── DEPLOYMENT-DASHBOARD.md        # Web console deployment guide
    └── NETWORK-REQUIREMENTS.md        # Network & firewall requirements
```

## File Descriptions

### Root Directory

| File | Purpose | When to Use |
|------|---------|-------------|
| **README.md** | Main documentation with architecture, API usage, troubleshooting | Start here for overview |
| **QUICKSTART.md** | Fast-track deployment guide | Want to deploy quickly |
| **deploy.sh** | Automated deployment script | Prefer automation over manual steps |
| **FILE-STRUCTURE.md** | This file - explains directory structure | Understanding package layout |

### manifests/ Directory

Kubernetes/OpenShift YAML files in numbered order (deploy in sequence):

| File | Resource Type | Purpose | Required? |
|------|---------------|---------|-----------|
| **01-namespace.yaml** | Namespace | Creates `llm-models` namespace | ✅ Yes |
| **02-pvc.yaml** | PersistentVolumeClaim | 300GB for model + 10GB for shared memory | ✅ Yes |
| **03-configmap.yaml** | ConfigMap | Model name, GPU settings, performance tuning | ✅ Yes |
| **04-secret.yaml** | Secret | HuggingFace token (template - needs your token) | ✅ Yes |
| **05-deployment.yaml** | Deployment | Main vLLM server pod with GPU, init container | ✅ Yes |
| **06-service.yaml** | Service | ClusterIP service on port 8000 | ✅ Yes |
| **07-route.yaml** | Route | External HTTPS access (OpenShift-specific) | ✅ Yes |
| **08-networkpolicy.yaml** | NetworkPolicy | Firewall rules for pod | ⚠️ Recommended |
| **09-servicemonitor.yaml** | ServiceMonitor | Prometheus metrics collection | ❌ Optional |

**Deployment Order:**
1. Namespace first
2. PVCs (wait for bound status)
3. ConfigMap and Secret
4. Deployment (will take 35-70 min)
5. Service and Route
6. NetworkPolicy and ServiceMonitor (optional)

### docs/ Directory

Comprehensive documentation:

| File | Audience | Content | Size |
|------|----------|---------|------|
| **DEPLOYMENT-CLI.md** | DevOps, CLI users | Step-by-step `oc` commands, troubleshooting, production tips | ~15 pages |
| **DEPLOYMENT-DASHBOARD.md** | GUI users, Admins | Web console walkthrough with screenshots guidance | ~18 pages |
| **NETWORK-REQUIREMENTS.md** | Network/Security teams | Firewall rules, ports, bandwidth, cloud security groups | ~20 pages |

## Usage Patterns

### Quick Deployment (Automated)

```bash
# One command deployment
./deploy.sh --token hf_YourTokenHere
```

**Uses:**
- All manifest files (01-09)
- Creates resources in order
- Waits for PVCs
- Shows progress and status

### Manual Deployment (Step-by-Step)

```bash
# Follow either guide:
docs/DEPLOYMENT-CLI.md        # For oc CLI
docs/DEPLOYMENT-DASHBOARD.md  # For web console
```

**Uses:**
- Manifests 01-07 (required)
- Manifests 08-09 (optional)
- Apply in numbered order

### Network Setup

```bash
# Read before deployment:
docs/NETWORK-REQUIREMENTS.md
```

**Contains:**
- Firewall rules for `huggingface.co`, `docker.io`, etc.
- Cloud security group examples (AWS, Azure, GCP)
- Bandwidth requirements (~250GB initial download)
- Proxy configuration
- Troubleshooting connectivity issues

## File Sizes

| Component | Size | Purpose |
|-----------|------|---------|
| All manifests | ~10 KB | Kubernetes YAML definitions |
| Documentation | ~50 KB | Comprehensive guides |
| Deployment script | ~12 KB | Bash automation |
| **Total Package** | **~75 KB** | Lightweight, portable |

**Runtime Downloads:**
- Docker image: ~10 GB (vLLM server)
- Model weights: ~250 GB (Kimi K2 Instruct)
- Python packages: ~500 MB

## Customization Points

### Change Model

Edit `manifests/03-configmap.yaml`:
```yaml
MODEL_NAME: "moonshotai/Kimi-K2-Instruct"  # Change this
```

Supported models:
- `moonshotai/Kimi-K2-Thinking`
- `meta-llama/Llama-2-7b-chat-hf`
- `mistralai/Mistral-7B-Instruct-v0.2`
- Any vLLM-compatible model

### Adjust GPU Settings

Edit `manifests/03-configmap.yaml`:
```yaml
MAX_MODEL_LEN: "8192"              # Context length
GPU_MEMORY_UTILIZATION: "0.90"     # GPU memory usage
TENSOR_PARALLEL_SIZE: "1"          # Number of GPUs
```

### Change Namespace

Option 1: Edit `manifests/01-namespace.yaml`
```yaml
metadata:
  name: my-custom-namespace  # Change from llm-models
```

Option 2: Use deployment script
```bash
./deploy.sh --token xxx --namespace my-custom-namespace
```

### Adjust Storage Size

Edit `manifests/02-pvc.yaml`:
```yaml
resources:
  requests:
    storage: 300Gi  # Increase for larger models
```

### Configure Route Hostname

Edit `manifests/07-route.yaml`:
```yaml
spec:
  host: kimi-k2.apps.your-cluster.com  # Custom hostname
```

## Deployment Scenarios

### Scenario 1: First-Time Deployment

**Files to use:**
1. `README.md` - Understand architecture
2. `QUICKSTART.md` - Fast deployment
3. `deploy.sh` - Run automated script
4. `docs/NETWORK-REQUIREMENTS.md` - If network issues

**Time:** 2-5 minutes setup + 35-70 minutes for model download

### Scenario 2: Manual CLI Deployment

**Files to use:**
1. `docs/DEPLOYMENT-CLI.md` - Follow step-by-step
2. `manifests/01-namespace.yaml` through `07-route.yaml`
3. `docs/NETWORK-REQUIREMENTS.md` - For firewall rules

**Time:** 10-15 minutes manual work + 35-70 minutes for model download

### Scenario 3: Web Console Deployment

**Files to use:**
1. `docs/DEPLOYMENT-DASHBOARD.md` - GUI walkthrough
2. All files in `manifests/` - Import via web console

**Time:** 15-20 minutes clicking through UI + 35-70 minutes for model download

### Scenario 4: Production Deployment

**Files to use:**
1. All manifests (customize first)
2. `docs/DEPLOYMENT-CLI.md` - Production considerations section
3. `manifests/08-networkpolicy.yaml` - Security (required)
4. `manifests/09-servicemonitor.yaml` - Monitoring (required)

**Additional steps:**
- Pin image versions (not `latest`)
- Use valid SSL certificates
- Set up backups
- Configure autoscaling
- Implement authentication

### Scenario 5: Troubleshooting Deployment

**Files to use:**
1. `README.md` - Troubleshooting section
2. `docs/DEPLOYMENT-CLI.md` - Troubleshooting section
3. `docs/NETWORK-REQUIREMENTS.md` - Network testing section

**Common issues:**
- GPU not available → Check GPU operator
- Model download fails → Check network connectivity
- Out of memory → Adjust ConfigMap settings
- Route not accessible → Check service endpoints

## Maintenance

### Update Model

```bash
# Edit ConfigMap
oc edit configmap kimi-k2-config -n llm-models
# Change MODEL_NAME

# Delete PVC to clear cache
oc delete pvc kimi-k2-model-cache -n llm-models

# Restart deployment
oc rollout restart deployment kimi-k2-vllm -n llm-models
```

### Update vLLM Version

```bash
# Edit deployment
oc edit deployment kimi-k2-vllm -n llm-models
# Change image: vllm/vllm-openai:latest to vllm/vllm-openai:v0.5.0

# Deployment will auto-rollout
```

### Scale Resources

```bash
# Edit deployment
oc edit deployment kimi-k2-vllm -n llm-models
# Adjust resources.requests and resources.limits
```

### Rotate HuggingFace Token

```bash
# Update secret
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=new_token \
  --dry-run=client -o yaml | oc apply -f -

# Restart
oc rollout restart deployment kimi-k2-vllm -n llm-models
```

## Version Control

This package is designed to be version-controlled:

```bash
# Initialize git repo
git init
git add .
git commit -m "Initial Kimi K2 deployment package"

# Track changes
git diff manifests/03-configmap.yaml  # See what changed
git log --oneline                      # View history
```

**Best practices:**
- Commit after each customization
- Use branches for different environments (dev/staging/prod)
- Tag releases: `git tag v1.0.0`
- Don't commit actual tokens (use placeholders)

## Multi-Environment Setup

Use branches for different environments:

```bash
# Development environment
git checkout -b dev
# Edit manifests for dev (smaller resources)
git commit -m "Dev environment config"

# Production environment
git checkout -b prod
# Edit manifests for prod (larger resources, specific versions)
git commit -m "Prod environment config"

# Deploy dev
git checkout dev
./deploy.sh --token xxx --namespace llm-dev

# Deploy prod
git checkout prod
./deploy.sh --token xxx --namespace llm-prod
```

## Dependencies

### External Dependencies

| Dependency | Purpose | How to Get |
|------------|---------|------------|
| **OpenShift CLI (oc)** | Deploy and manage | https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html |
| **HuggingFace Token** | Download models | https://huggingface.co/settings/tokens |
| **NVIDIA GPU Operator** | GPU support | Install via OperatorHub in OpenShift |
| **Storage Class** | Dynamic PVC provisioning | Verify with: `oc get storageclass` |

### Runtime Dependencies (Auto-downloaded)

| Dependency | Source | Size |
|------------|--------|------|
| **vLLM Docker Image** | Docker Hub | ~10 GB |
| **Kimi K2 Model** | HuggingFace | ~250 GB |
| **Python Packages** | PyPI | ~500 MB |

All runtime dependencies are automatically downloaded during deployment.

## Security Considerations

### Sensitive Files

| File | Sensitivity | Handling |
|------|-------------|----------|
| **04-secret.yaml** | 🔴 High | Do NOT commit with real tokens |
| **deploy.sh** | ⚠️ Medium | Token passed as argument (not stored) |
| Other manifests | ✅ Safe | Can be committed to git |

### Best Practices

1. **Never commit secrets**
   ```bash
   # Add to .gitignore
   echo "manifests/*secret*.yaml" >> .gitignore
   echo "*.token" >> .gitignore
   ```

2. **Use external secrets management**
   - AWS Secrets Manager
   - HashiCorp Vault
   - OpenShift External Secrets Operator

3. **Apply NetworkPolicies**
   - Always use `08-networkpolicy.yaml` in production
   - Restricts ingress/egress traffic

4. **Review permissions**
   ```bash
   # Check what service account can do
   oc auth can-i --list --as=system:serviceaccount:llm-models:default
   ```

## Summary

This package provides three deployment paths:

1. **🚀 Fastest**: Run `./deploy.sh --token xxx` (automated)
2. **🎯 Controlled**: Follow `docs/DEPLOYMENT-CLI.md` (manual)
3. **🖱️ Visual**: Follow `docs/DEPLOYMENT-DASHBOARD.md` (GUI)

All paths use the same manifests and result in identical deployments.

**Package Contents:**
- ✅ 9 ready-to-use Kubernetes manifests
- ✅ 1 automated deployment script
- ✅ 3 comprehensive documentation guides
- ✅ Production-ready configuration
- ✅ Security best practices included
- ✅ GPU optimization for Tesla T4+

**Estimated Total Time:**
- Setup: 2-15 minutes (depending on method)
- Model download: 30-60 minutes
- Server startup: 5-10 minutes
- **Total: 35-70 minutes to running API**

Choose your path and get started! 🎉
