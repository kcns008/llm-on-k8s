# Quick Start Guide - Kimi K2 Instruct 0905 on OpenShift

Get your Kimi K2 Instruct 0905 model running on OpenShift in under 5 minutes!

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] OpenShift cluster with GPU nodes (Tesla T4, A10, or A100)
- [ ] `oc` CLI installed and logged in
- [ ] NVIDIA GPU Operator installed
- [ ] At least 300GB storage available
- [ ] Hugging Face token: https://huggingface.co/settings/tokens

## Step 1: Login to OpenShift

```bash
oc login --server=https://api.your-cluster.com:6443 --token=YOUR_TOKEN
```

## Step 2: Clone/Download This Repository

```bash
cd openshift-kimi-k2-0905-vllm
```

## Step 3: Deploy Infrastructure

```bash
# Create namespace
oc apply -f manifests/01-namespace.yaml

# Create persistent storage
oc apply -f manifests/02-pvc.yaml

# Create configuration
oc apply -f manifests/03-configmap.yaml
```

## Step 4: Configure Secret

Create your Hugging Face token secret:

```bash
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_your_token_here \
  -n llm-kimi-k2-0905
```

## Step 5: Deploy the Model

```bash
# Deploy the vLLM server
oc apply -f manifests/05-deployment.yaml

# Create service
oc apply -f manifests/06-service.yaml

# Create route
oc apply -f manifests/07-route.yaml

# Apply network policies
oc apply -f manifests/08-networkpolicy.yaml
```

## Step 6: Wait for Deployment

The deployment will:
1. Download the model from Hugging Face (~35-70 minutes)
2. Load the model into GPU memory (~5-10 minutes)
3. Start serving requests

### Monitor Progress

```bash
# Watch pod status
oc get pods -n llm-kimi-k2-0905 -w

# Check model download progress
oc logs -f -n llm-kimi-k2-0905 -l app=kimi-k2-0905 -c model-downloader

# Check server startup
oc logs -f -n llm-kimi-k2-0905 -l app=kimi-k2-0905 -c vllm-server
```

## Step 7: Get Your API URL

```bash
oc get route kimi-k2-0905-vllm -n llm-kimi-k2-0905 -o jsonpath='{.spec.host}'
```

Save this URL - you'll use it to make API calls!

## Step 8: Test Your Deployment

### Health Check

```bash
ROUTE_URL=$(oc get route kimi-k2-0905-vllm -n llm-kimi-k2-0905 -o jsonpath='{.spec.host}')
curl https://$ROUTE_URL/health
```

Expected response:
```json
{"status":"ok"}
```

### List Available Models

```bash
curl https://$ROUTE_URL/v1/models
```

### Make Your First Chat Request

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

### Local Testing (Optional)

If you want to test locally:

```bash
# Port forward to localhost
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

## Quick Commands Reference

### Check Deployment Status

```bash
# Pod status
oc get pods -n llm-kimi-k2-0905

# Deployment status
oc get deployment -n llm-kimi-k2-0905

# Service status
oc get svc -n llm-kimi-k2-0905

# Route URL
oc get route -n llm-kimi-k2-0905
```

### View Logs

```bash
# Current logs
oc logs -l app=kimi-k2-0905 -c vllm-server -n llm-kimi-k2-0905

# Follow logs
oc logs -f -l app=kimi-k2-0905 -c vllm-server -n llm-kimi-k2-0905

# Init container logs
oc logs -l app=kimi-k2-0905 -c model-downloader -n llm-kimi-k2-0905
```

### Resource Usage

```bash
# Pod resource usage
oc adm top pod -n llm-kimi-k2-0905

# Node resource usage
oc adm top nodes
```

## Common Issues & Quick Fixes

### Pod Stuck in Pending

**Check GPU availability:**
```bash
oc describe pod -l app=kimi-k2-0905 -n llm-kimi-k2-0905 | grep -A 5 Events
```

**Solution:** Ensure GPU nodes are available and GPU Operator is installed.

### Model Download Taking Too Long

**This is normal!** The model is large (~247GB). Download can take 35-70 minutes depending on network speed.

**Check progress:**
```bash
oc logs -f -l app=kimi-k2-0905 -c model-downloader -n llm-kimi-k2-0905
```

### Pod Crashes with OOM

**Solution:** Reduce context length in ConfigMap:
```bash
oc edit configmap kimi-k2-0905-config -n llm-kimi-k2-0905
```

Change `MAX_MODEL_LEN` to a lower value (e.g., 8192).

### Route Returns 503

**Wait for pod to be ready:**
```bash
oc get pods -n llm-kimi-k2-0905
```

Status should be `Running` and `READY` should be `1/1`.

## Using with Python

```python
from openai import OpenAI

# Get your route URL from:
# oc get route kimi-k2-0905-vllm -n llm-kimi-k2-0905
client = OpenAI(
    base_url="https://your-route-url/v1",
    api_key="not-used"
)

response = client.chat.completions.create(
    model="moonshotai/Kimi-K2-Instruct-0905",
    messages=[
        {"role": "user", "content": "Explain quantum computing"}
    ]
)

print(response.choices[0].message.content)
```

## Next Steps

1. **Configure for your GPU** - Edit `03-configmap.yaml` for optimal settings
2. **Set up monitoring** - Apply `09-servicemonitor.yaml` if using Prometheus
3. **Add authentication** - Implement OAuth proxy or API gateway
4. **Scale up** - Use multiple GPUs for better performance
5. **Read full documentation** - Check [README.md](README.md) for details

## Cleanup

To remove everything:

```bash
# Delete all resources
oc delete -f manifests/

# Or delete entire namespace
oc delete namespace llm-kimi-k2-0905
```

## Need Help?

- Check logs: `oc logs -l app=kimi-k2-0905 -n llm-kimi-k2-0905 --all-containers`
- Check events: `oc get events -n llm-kimi-k2-0905 --sort-by='.lastTimestamp'`
- Read full docs: [README.md](README.md)

---

**That's it!** You now have Kimi K2 Instruct 0905 running on OpenShift with vLLM. 🚀
