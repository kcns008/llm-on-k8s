# Kimi K2 on ARO - Quickstart Guide

Get Kimi K2 LLM running on Azure Red Hat OpenShift with llama.cpp in **5 minutes** (plus download time).

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] OpenShift/ARO cluster with GPU nodes (Tesla T4 or better)
- [ ] NVIDIA GPU Operator installed
- [ ] `oc` CLI installed locally
- [ ] Cluster admin or project admin access
- [ ] Hugging Face account and token ([get here](https://huggingface.co/settings/tokens))
- [ ] 400GB+ available storage in your cluster

## Step 1: Login to Your Cluster

```bash
# Get your login command from OpenShift Console
# Click your username → "Copy login command"
oc login --server=https://api.your-cluster.com:6443 --token=sha256~xxx
```

## Step 2: Deploy Infrastructure

```bash
# Navigate to deployment folder
cd openshift-kimi-k2-llamacpp

# Create namespace
oc apply -f manifests/01-namespace.yaml

# Create persistent storage (400GB)
oc apply -f manifests/02-pvc.yaml

# Verify PVC is bound
oc get pvc -n llm-models-llamacpp
# Should show STATUS: Bound
```

## Step 3: Configure the Model

```bash
# Apply configuration (default: Kimi-K2-Thinking, UD-TQ1_0 quant)
oc apply -f manifests/03-configmap.yaml

# (Optional) Edit config to change model or quantization
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
```

### Configuration Options

| Setting | Default | Alternatives |
|---------|---------|--------------|
| **Model** | Kimi-K2-Thinking | Kimi-K2-Instruct |
| **Quantization** | UD-TQ1_0 (247GB) | UD-Q2_K_XL (381GB), UD-Q4_K_XL (588GB) |
| **Temperature** | 1.0 (Thinking) | 0.6 (Instruct) |
| **Context Size** | 16384 | 8192, 32768, 98304 |

## Step 4: Add HuggingFace Token

```bash
# Create secret with your token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_xxxxxxxxxxxxx \
  -n llm-models-llamacpp

# Verify secret was created
oc get secret huggingface-token -n llm-models-llamacpp
```

**Get your token:** https://huggingface.co/settings/tokens (needs read access)

## Step 5: Deploy the Application

```bash
# Deploy llama.cpp server
oc apply -f manifests/05-deployment.yaml

# Create service
oc apply -f manifests/06-service.yaml

# Create external route
oc apply -f manifests/07-route.yaml

# (Optional) Apply network policies
oc apply -f manifests/08-networkpolicy.yaml
```

## Step 6: Monitor Deployment Progress

The deployment has **2 init containers** that run before the main server:

### 6.1 Watch llama.cpp Build (10-15 minutes)

```bash
# Follow build logs
oc logs -f -n llm-models-llamacpp \
  -l app=kimi-k2-llamacpp \
  -c build-llamacpp

# You'll see: "Building llama.cpp with CUDA support..."
# Wait for: "llama.cpp build complete!"
```

### 6.2 Watch Model Download (30-90 minutes)

```bash
# Follow download logs
oc logs -f -n llm-models-llamacpp \
  -l app=kimi-k2-llamacpp \
  -c model-downloader

# You'll see progress bars for GGUF file downloads
# UD-TQ1_0: ~247GB (6 files)
# UD-Q2_K_XL: ~381GB (7 files)
```

**Download times (typical):**
- UD-TQ1_0 (247GB): 30-45 minutes (with 1 Gbps)
- UD-Q2_K_XL (381GB): 45-70 minutes (with 1 Gbps)

### 6.3 Watch Server Startup (2-5 minutes)

```bash
# Once init containers complete, watch main server
oc logs -f -n llm-models-llamacpp \
  -l app=kimi-k2-llamacpp \
  -c llama-server

# Wait for: "llama-server listening on 0.0.0.0:8001"
```

## Step 7: Get Your API Endpoint

```bash
# Get the route URL
ROUTE_URL=$(oc get route kimi-k2-llamacpp \
  -n llm-models-llamacpp \
  -o jsonpath='{.spec.host}')

echo "Your API endpoint: https://$ROUTE_URL"
```

## Step 8: Test the API

### Health Check

```bash
curl https://$ROUTE_URL/health
# Expected: {"status":"ok"}
```

### List Models

```bash
curl https://$ROUTE_URL/v1/models
```

### First Chat Completion

```bash
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2-thinking",
    "messages": [
      {"role": "system", "content": "You are Kimi, an AI assistant."},
      {"role": "user", "content": "What is 2+2? Think step by step."}
    ],
    "max_tokens": 200,
    "temperature": 1.0
  }' | jq .
```

### Python Example

```python
from openai import OpenAI

client = OpenAI(
    base_url=f"https://{ROUTE_URL}/v1",  # Your route URL
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="kimi-k2-thinking",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    temperature=1.0,
    max_tokens=500
)

print(response.choices[0].message.content)
```

## Verification Checklist

After deployment, verify:

- [ ] PVC is bound: `oc get pvc -n llm-models-llamacpp`
- [ ] Pod is running: `oc get pods -n llm-models-llamacpp`
- [ ] Init containers completed: `oc describe pod -n llm-models-llamacpp`
- [ ] Server logs show "listening": `oc logs -l app=kimi-k2-llamacpp -c llama-server`
- [ ] Health endpoint responds: `curl https://$ROUTE_URL/health`
- [ ] Chat completion works: Test with curl or Python

## Troubleshooting

### Pod Stuck in Init

**Check which init container:**
```bash
oc get pods -n llm-models-llamacpp
# Look at READY column: 0/1 means init running
```

**Check init logs:**
```bash
# For build issues
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c build-llamacpp

# For download issues
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader
```

### Common Issues

| Issue | Solution |
|-------|----------|
| **PVC not bound** | Check storage class exists: `oc get sc` |
| **Init OOMKilled** | Increase init container memory in `05-deployment.yaml` |
| **Download timeout** | Network issue - check egress to huggingface.co:443 |
| **Server crashes** | Check GPU available: `oc describe node \| grep nvidia` |
| **404 on route** | Wait for pod to be Ready, check service endpoints |

### Get Detailed Status

```bash
# Full pod description
oc describe pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# All events
oc get events -n llm-models-llamacpp --sort-by='.lastTimestamp'

# Resource usage
oc adm top pod -n llm-models-llamacpp

# GPU node check
oc get nodes -l nvidia.com/gpu.present=true
```

## Next Steps

✅ **You're ready!** Your Kimi K2 LLM is now deployed.

**What to do next:**
1. 📖 Read [Full Documentation](README.md) for advanced features
2. ⚙️ Adjust [ConfigMap](manifests/03-configmap.yaml) to tune performance
3. 📊 Set up monitoring (Prometheus, Grafana)
4. 🔒 Add authentication (OAuth proxy, API gateway)
5. 🚀 Scale horizontally (multiple replicas with different quants)

**Performance tuning:**
- Try different quantizations (UD-Q2_K_XL for better quality)
- Adjust context size based on use case
- Tune MoE offloading based on available VRAM
- Monitor GPU utilization: `nvidia-smi`

## Quick Reference

```bash
# Restart deployment
oc rollout restart deployment kimi-k2-llamacpp -n llm-models-llamacpp

# Scale down (to save resources)
oc scale deployment kimi-k2-llamacpp --replicas=0 -n llm-models-llamacpp

# Scale up
oc scale deployment kimi-k2-llamacpp --replicas=1 -n llm-models-llamacpp

# Update config (then restart)
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
oc rollout restart deployment kimi-k2-llamacpp -n llm-models-llamacpp

# Delete everything
oc delete -f manifests/

# Delete but keep model cache
oc delete deployment,service,route,configmap,secret -n llm-models-llamacpp --all
```

---

**Need help?** Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md) or [Full README](README.md).
