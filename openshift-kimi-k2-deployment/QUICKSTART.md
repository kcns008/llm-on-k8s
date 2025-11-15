# Quick Start Guide - Kimi K2 on OpenShift

Get your Kimi K2 LLM running on OpenShift in under 5 minutes (plus download time).

## Prerequisites

Before you begin, ensure you have:

1. **OpenShift Cluster Access**
   - OpenShift 4.x cluster with GPU nodes
   - Cluster admin or namespace admin permissions
   - `oc` CLI installed on your machine

2. **Hugging Face Token**
   - Get free token: https://huggingface.co/settings/tokens
   - Requires "read" access permissions

3. **Cluster Requirements**
   - At least one GPU node (NVIDIA Tesla T4 or better)
   - NVIDIA GPU Operator installed
   - 300GB+ storage available
   - Network access to huggingface.co (see Network Requirements doc)

## Option 1: Automated Deployment (Recommended)

### Step 1: Login to OpenShift

```bash
oc login --server=https://api.your-cluster.example.com:6443 --token=YOUR_TOKEN
```

### Step 2: Run Deployment Script

```bash
cd openshift-kimi-k2-deployment

# Replace with your actual Hugging Face token
./deploy.sh --token hf_YourHuggingFaceTokenHere
```

That's it! The script will:
- ✅ Create namespace and all resources
- ✅ Configure storage and settings
- ✅ Deploy the model server
- ✅ Set up external access
- ✅ Show you the API URL

**Time:** 35-70 minutes total (mostly model download time)

### Advanced Script Options

```bash
# Custom namespace
./deploy.sh --token hf_xxx --namespace my-llm

# Skip namespace creation (if already exists)
./deploy.sh --token hf_xxx --skip-namespace

# Skip PVC creation (if already exists)
./deploy.sh --token hf_xxx --skip-pvc

# Enable Prometheus monitoring
./deploy.sh --token hf_xxx --enable-monitoring

# No network policy
./deploy.sh --token hf_xxx --no-network-policy
```

## Option 2: Manual Deployment (Step-by-Step)

### Step 1: Login and Create Namespace

```bash
oc login --server=https://api.your-cluster.example.com:6443

cd openshift-kimi-k2-deployment

oc apply -f manifests/01-namespace.yaml
oc project llm-models
```

### Step 2: Create Storage

```bash
oc apply -f manifests/02-pvc.yaml
oc get pvc -w  # Wait for "Bound" status (Ctrl+C to exit)
```

### Step 3: Create Configuration

```bash
oc apply -f manifests/03-configmap.yaml
```

### Step 4: Create Secret with Your Token

```bash
# Replace with your actual Hugging Face token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_YourHuggingFaceTokenHere \
  -n llm-models
```

### Step 5: Deploy the Model

```bash
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
```

### Step 6: Optional Security and Monitoring

```bash
# Network policy (recommended for production)
oc apply -f manifests/08-networkpolicy.yaml

# Prometheus monitoring (if you have Prometheus operator)
oc apply -f manifests/09-servicemonitor.yaml
```

## Monitor Deployment Progress

### Watch Pod Status

```bash
oc get pods -n llm-models -w
```

**Status progression:**
1. `Pending` - Waiting for resources
2. `Init:0/1` - Downloading model (~30-60 min)
3. `Running` - Starting server (~5-10 min)
4. `Ready` - Ready to serve requests ✓

### View Download Progress

```bash
# Model download logs
oc logs -f -l app=kimi-k2 -c model-downloader -n llm-models
```

### View Server Logs

```bash
# Server startup and runtime logs
oc logs -f -l app=kimi-k2 -c vllm-server -n llm-models
```

### Get API URL

```bash
oc get route kimi-k2-vllm -n llm-models -o jsonpath='{.spec.host}'
```

Save this URL - you'll use it to access the API!

## Test Your Deployment

### 1. Health Check

```bash
KIMI_URL=$(oc get route kimi-k2-vllm -n llm-models -o jsonpath='{.spec.host}')
curl https://$KIMI_URL/health
```

**Expected:** `{"status":"ok"}`

### 2. List Models

```bash
curl https://$KIMI_URL/v1/models
```

**Expected:** JSON with model info

### 3. Test Completion

```bash
curl https://$KIMI_URL/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "prompt": "What is artificial intelligence?",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### 4. Test Chat

```bash
curl https://$KIMI_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    "max_tokens": 200
  }'
```

## Using the API

### With Python (OpenAI SDK)

```python
from openai import OpenAI

# Replace with your route URL
client = OpenAI(
    base_url="https://your-route-url/v1",
    api_key="not-used"
)

response = client.chat.completions.create(
    model="kimi-k2",
    messages=[
        {"role": "user", "content": "Write a haiku about AI"}
    ]
)

print(response.choices[0].message.content)
```

### With curl

```bash
curl https://$KIMI_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

### With JavaScript (fetch)

```javascript
const response = await fetch('https://your-route-url/v1/chat/completions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model: 'kimi-k2',
    messages: [{ role: 'user', content: 'Hello!' }],
    max_tokens: 50
  })
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

## Troubleshooting Quick Fixes

### Pod Won't Start

```bash
# Check what's wrong
oc describe pod -l app=kimi-k2 -n llm-models

# Check events
oc get events -n llm-models --sort-by='.lastTimestamp' | tail -20
```

**Common issues:**
- No GPU available → Install GPU operator or check node labels
- PVC not bound → Check storage class exists
- Image pull error → Check network connectivity

### Model Download Failing

```bash
# Check init container logs
oc logs -l app=kimi-k2 -c model-downloader -n llm-models
```

**Common issues:**
- Invalid token → Update secret with correct token
- Network blocked → Check firewall rules (see NETWORK-REQUIREMENTS.md)
- Disk full → Increase PVC size

### Can't Access Route

```bash
# Check service endpoints
oc get endpoints kimi-k2-vllm -n llm-models

# Test from inside cluster
oc run curl-test --image=curlimages/curl -it --rm -- \
  curl http://kimi-k2-vllm.llm-models.svc.cluster.local:8000/health
```

### Out of Memory

```bash
# Check resource usage
oc adm top pod -l app=kimi-k2 -n llm-models
```

**Fix:** Edit ConfigMap and reduce `MAX_MODEL_LEN`:
```bash
oc edit configmap kimi-k2-config -n llm-models
# Change MAX_MODEL_LEN to "4096" or "2048"

# Restart deployment
oc rollout restart deployment kimi-k2-vllm -n llm-models
```

## Configuration Tuning

### For Tesla T4 (16GB GPU)

Best settings for budget GPU:

```bash
oc edit configmap kimi-k2-config -n llm-models
```

Set:
```yaml
MAX_MODEL_LEN: "8192"
GPU_MEMORY_UTILIZATION: "0.90"
SWAP_SPACE: "16"
```

### For A100 (40GB+ GPU)

Maximize performance:

```yaml
MAX_MODEL_LEN: "32768"
GPU_MEMORY_UTILIZATION: "0.95"
SWAP_SPACE: "0"
```

### Change Model

```bash
oc edit configmap kimi-k2-config -n llm-models
```

Change `MODEL_NAME` to any compatible model:
- `moonshotai/Kimi-K2-Thinking` - Reasoning model
- `meta-llama/Llama-2-7b-chat-hf` - Llama 2
- `mistralai/Mistral-7B-Instruct-v0.2` - Mistral

Then restart:
```bash
oc rollout restart deployment kimi-k2-vllm -n llm-models
```

## Cleanup

### Delete Everything

```bash
# Delete all resources
oc delete -f manifests/

# Or delete just the namespace
oc delete namespace llm-models
```

### Keep Model Cache

To avoid re-downloading later:

```bash
# Delete deployment but keep PVCs
oc delete deployment,service,route,configmap -n llm-models --all

# Later, redeploy quickly
./deploy.sh --token hf_xxx --skip-namespace --skip-pvc
```

## Next Steps

Once your model is running:

1. **Add Authentication**
   - Set up OAuth proxy
   - Implement API keys
   - Configure RBAC

2. **Enable Monitoring**
   - Apply ServiceMonitor
   - Create Grafana dashboards
   - Set up alerts

3. **Optimize Performance**
   - Tune GPU settings
   - Enable autoscaling
   - Set up load balancing

4. **Production Hardening**
   - Use specific image versions (not `latest`)
   - Set up backups
   - Document runbook
   - Configure rate limiting

## Get More Help

- **Detailed CLI Guide**: [docs/DEPLOYMENT-CLI.md](docs/DEPLOYMENT-CLI.md)
- **Web Console Guide**: [docs/DEPLOYMENT-DASHBOARD.md](docs/DEPLOYMENT-DASHBOARD.md)
- **Network Setup**: [docs/NETWORK-REQUIREMENTS.md](docs/NETWORK-REQUIREMENTS.md)
- **Main README**: [README.md](README.md)

## Timeline

**Initial Deployment:**
- Setup commands: 2-5 minutes
- Model download: 30-60 minutes (depends on network)
- Server startup: 5-10 minutes
- **Total: 35-70 minutes**

**Subsequent Deploys:**
- If model is cached: 5-10 minutes
- If PVCs exist: 2-5 minutes

## Support

For issues:
1. Check logs: `oc logs -l app=kimi-k2 --all-containers -n llm-models`
2. Check events: `oc get events -n llm-models`
3. Review troubleshooting section above
4. Consult detailed guides in `docs/`

---

**Ready?** Run `./deploy.sh --token YOUR_TOKEN` and you're on your way! 🚀
