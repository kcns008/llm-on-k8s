# GLM-4.6 on ARO - Quick Start Guide

Get GLM-4.6 running on Azure Red Hat OpenShift in under 5 minutes!

## Prerequisites

- OpenShift/ARO cluster with GPU nodes (Tesla T4 or better)
- NVIDIA GPU Operator installed
- `oc` CLI configured
- Hugging Face token: https://huggingface.co/settings/tokens
- 200GB+ storage available

## Step 1: Login to Cluster

```bash
oc login --server=https://api.your-cluster.com:6443 --token=YOUR_TOKEN
```

## Step 2: Create Namespace & Storage

```bash
cd openshift-glm46-llamacpp

oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-pvc.yaml
```

## Step 3: Configure Model Settings

```bash
oc apply -f manifests/03-configmap.yaml
```

**Optional:** Edit `manifests/03-configmap.yaml` to change:
- `QUANT_TYPE`: Model size (UD-TQ1_0=84GB, UD-Q2_K_XL=135GB, UD-Q4_K_XL=204GB)
- `CTX_SIZE`: Context length (8192, 16384, 32768, or up to 200000)
- `MoE_OFFLOAD`: CPU offloading strategy

## Step 4: Create HuggingFace Secret

```bash
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_your_actual_token_here \
  -n llm-models-glm46
```

## Step 5: Deploy GLM-4.6

```bash
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
oc apply -f manifests/08-networkpolicy.yaml
```

## Step 6: Monitor Deployment

Watch the deployment progress:

```bash
# Check pod status
oc get pods -n llm-models-glm46 -w

# Watch build progress (10-15 min)
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c build-llamacpp

# Watch model download (30-90 min depending on quant size)
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c model-downloader

# Watch server startup
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c llama-server
```

## Step 7: Get API URL

```bash
ROUTE_URL=$(oc get route glm46-llamacpp -n llm-models-glm46 -o jsonpath='{.spec.host}')
echo "GLM-4.6 API URL: https://$ROUTE_URL"
```

## Step 8: Test the API

```bash
# Health check
curl https://$ROUTE_URL/health

# Test completion
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.6",
    "messages": [
      {"role": "user", "content": "Write a Python function to reverse a string."}
    ],
    "max_tokens": 500,
    "temperature": 1.0,
    "top_p": 0.95,
    "top_k": 40
  }'
```

## Expected Timeline

| Stage | Duration | Notes |
|-------|----------|-------|
| Namespace/PVC creation | 1-2 min | Instant if storage is pre-provisioned |
| llama.cpp build | 10-15 min | One-time, cached for future deployments |
| Model download (UD-TQ1_0) | 20-30 min | 84GB |
| Model download (UD-Q2_K_XL) | 30-60 min | 135GB |
| Model download (UD-Q4_K_XL) | 60-90 min | 204GB |
| Server startup | 2-5 min | Model loading into memory |

**Total:** 45-120 minutes depending on quantization choice

## Python Test Script

Save as `test_glm46.py`:

```python
from openai import OpenAI

# Replace with your actual route URL
client = OpenAI(
    base_url="https://YOUR-ROUTE-URL/v1",
    api_key="not-needed"
)

# Test coding task (GLM-4.6 excels at this!)
response = client.chat.completions.create(
    model="glm-4.6",
    messages=[
        {"role": "user", "content": "Write a Python function to find prime numbers up to n using Sieve of Eratosthenes."}
    ],
    temperature=1.0,
    top_p=0.95,
    top_k=40,
    max_tokens=1000
)

print(response.choices[0].message.content)
```

Run it:

```bash
pip install openai
python test_glm46.py
```

## Quick Configuration Changes

### Switch to Smaller Model (Faster Download)

```bash
# Edit configmap
oc edit configmap glm46-llamacpp-config -n llm-models-glm46

# Change QUANT_TYPE to:
# QUANT_TYPE: "UD-TQ1_0"  # 84GB instead of 135GB

# Restart deployment
oc rollout restart deployment glm46-llamacpp -n llm-models-glm46
```

### Increase Context Length

```bash
oc edit configmap glm46-llamacpp-config -n llm-models-glm46

# Change CTX_SIZE to:
# CTX_SIZE: "32768"  # or "65536" or "200000"

oc rollout restart deployment glm46-llamacpp -n llm-models-glm46
```

## Troubleshooting

### Pod Not Starting

```bash
# Check events
oc describe pod -n llm-models-glm46 -l app=glm-4.6-llamacpp

# Common issues:
# - No GPU nodes available
# - Insufficient memory
# - PVC not bound
```

### Out of Memory

```bash
# Use smaller quant or increase memory limits
oc edit deployment glm46-llamacpp -n llm-models-glm46

# Increase resources.limits.memory to 256Gi or reduce quant to UD-TQ1_0
```

### Slow Download

```bash
# Check download progress
oc logs -f -n llm-models-glm46 -l app=glm-4.6-llamacpp -c model-downloader

# Downloads can take 30-90 minutes - be patient!
```

### Chat Template Issues

```bash
# Verify --jinja flag is present
oc logs -n llm-models-glm46 -l app=glm-4.6-llamacpp -c llama-server | grep jinja

# Should show: --jinja in the llama-server command
```

## Cleanup

```bash
# Delete everything
oc delete namespace llm-models-glm46

# Or keep PVC for faster redeployment
oc delete deployment,service,route,configmap,secret,networkpolicy \
  -n llm-models-glm46 --all
```

## Next Steps

- Read full [README.md](README.md) for detailed configuration
- Explore [Unsloth GLM-4.6 docs](https://docs.unsloth.ai/models/glm-4.6-how-to-run-locally)
- Monitor GPU usage with `nvidia-smi`
- Test coding and reasoning tasks (GLM-4.6's strengths!)

## Performance Tips

**For Tesla T4 (16GB VRAM):**
- Use `UD-TQ1_0` quant (84GB)
- Keep context at 8192 or 16384
- Expect 3-5 tokens/second
- Full MoE offloading: `.ffn_.*_exps.=CPU`

**For A10/A10G (24GB VRAM):**
- Use `UD-Q2_K_XL` quant (135GB)
- Context up to 32768
- Expect 5-8 tokens/second
- Partial MoE offloading: `.ffn_(up|down)_exps.=CPU`

---

**Questions?** Check the [README.md](README.md) for detailed docs!
