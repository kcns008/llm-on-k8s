# Kimi K2 Deployment Guide - OpenShift CLI (oc)

This guide explains how to deploy the Kimi K2 LLM model on OpenShift using the `oc` command-line tool.

## Prerequisites

### 1. CLI Tools
- OpenShift CLI (`oc`) installed and configured
- Access to OpenShift cluster with GPU nodes
- Cluster admin or sufficient permissions to create namespaces and deployments

### 2. Cluster Requirements
- **GPU Nodes**: At least one node with NVIDIA Tesla T4 GPU (or better)
- **GPU Operator**: NVIDIA GPU Operator installed on the cluster
- **Storage**: Storage class that supports ReadWriteOnce with at least 300GB available
- **Memory**: Nodes with at least 64GB RAM for optimal performance
- **Network**: Outbound HTTPS access to download models from Hugging Face

### 3. Hugging Face Token
Get a Hugging Face token from: https://huggingface.co/settings/tokens
- Token needs read access to download models
- Keep this token secure

## Step-by-Step Deployment

### Step 1: Login to OpenShift Cluster

```bash
# Login to your OpenShift cluster
oc login --server=https://api.your-cluster.example.com:6443 --token=YOUR_TOKEN

# Or with username/password
oc login --server=https://api.your-cluster.example.com:6443 -u admin -p password
```

### Step 2: Verify GPU Availability

```bash
# Check if GPU nodes are available
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU operator status
oc get pods -n nvidia-gpu-operator

# View GPU resources on nodes
oc describe nodes | grep -A 5 "nvidia.com/gpu"
```

### Step 3: Navigate to Deployment Directory

```bash
cd openshift-kimi-k2-deployment
```

### Step 4: Create Namespace

```bash
# Create the namespace
oc apply -f manifests/01-namespace.yaml

# Verify namespace creation
oc get namespace llm-models

# Switch to the namespace
oc project llm-models
```

### Step 5: Create Persistent Volume Claims

```bash
# Create PVCs for model storage and shared memory
oc apply -f manifests/02-pvc.yaml

# Verify PVC creation
oc get pvc -n llm-models

# Wait for PVCs to be bound (may take a few moments)
oc get pvc -n llm-models -w
```

Expected output:
```
NAME                    STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
kimi-k2-model-cache     Bound    pvc-xxx   300Gi      RWO            gp3            1m
kimi-k2-shm             Bound    pvc-yyy   10Gi       RWO            gp3            1m
```

### Step 6: Create ConfigMap

```bash
# Create configuration
oc apply -f manifests/03-configmap.yaml

# Verify ConfigMap
oc get configmap kimi-k2-config -n llm-models
oc describe configmap kimi-k2-config -n llm-models
```

### Step 7: Create Hugging Face Secret

**Option A: Using the manifest (edit first)**

```bash
# Edit the secret file and replace YOUR_HUGGINGFACE_TOKEN_HERE
vi manifests/04-secret.yaml

# Apply the secret
oc apply -f manifests/04-secret.yaml
```

**Option B: Using command line (recommended)**

```bash
# Create secret directly with your token
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_YourActualTokenHere \
  -n llm-models

# Verify secret creation
oc get secret huggingface-token -n llm-models
```

### Step 8: Deploy Kimi K2 vLLM Server

```bash
# Deploy the vLLM server
oc apply -f manifests/05-deployment.yaml

# Watch the deployment progress
oc get pods -n llm-models -w
```

**Monitor the deployment:**

```bash
# Check deployment status
oc get deployment kimi-k2-vllm -n llm-models

# View pod details
oc describe pod -l app=kimi-k2 -n llm-models

# Follow logs (init container - model download)
oc logs -f -l app=kimi-k2 -c model-downloader -n llm-models

# Follow logs (main container - vLLM server)
oc logs -f -l app=kimi-k2 -c vllm-server -n llm-models
```

**Note:** The init container will download the model (~250GB), which can take 30-60 minutes depending on your network speed. The pod will show `Init:0/1` status during this time.

### Step 9: Create Service

```bash
# Create the service
oc apply -f manifests/06-service.yaml

# Verify service
oc get svc kimi-k2-vllm -n llm-models
oc describe svc kimi-k2-vllm -n llm-models
```

### Step 10: Create Route (External Access)

```bash
# Create the route
oc apply -f manifests/07-route.yaml

# Get the route URL
oc get route kimi-k2-vllm -n llm-models

# Or get just the URL
export KIMI_URL=$(oc get route kimi-k2-vllm -n llm-models -o jsonpath='{.spec.host}')
echo "Kimi K2 API URL: https://$KIMI_URL"
```

### Step 11: Apply Network Policy (Optional)

```bash
# Apply network policy for security
oc apply -f manifests/08-networkpolicy.yaml

# Verify network policy
oc get networkpolicy -n llm-models
```

### Step 12: Apply Service Monitor (Optional - for Prometheus)

```bash
# Only if you have Prometheus operator installed
oc apply -f manifests/09-servicemonitor.yaml

# Verify
oc get servicemonitor -n llm-models
```

## Verification and Testing

### Check Health Endpoint

```bash
# Get the route
KIMI_URL=$(oc get route kimi-k2-vllm -n llm-models -o jsonpath='{.spec.host}')

# Test health endpoint
curl https://$KIMI_URL/health

# Expected response: {"status":"ok"} or similar
```

### List Available Models

```bash
curl https://$KIMI_URL/v1/models
```

Expected response:
```json
{
  "object": "list",
  "data": [
    {
      "id": "kimi-k2",
      "object": "model",
      "created": 1234567890,
      "owned_by": "vllm"
    }
  ]
}
```

### Test Inference

```bash
curl https://$KIMI_URL/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "prompt": "Explain quantum computing in simple terms:",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### Test Chat Completion

```bash
curl https://$KIMI_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "max_tokens": 50
  }'
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
oc describe pod -l app=kimi-k2 -n llm-models

# Check pod logs
oc logs -l app=kimi-k2 -n llm-models --all-containers=true

# Common issues:
# 1. GPU not available - check GPU operator
# 2. Storage not bound - check PVC status
# 3. Image pull errors - check network connectivity
```

### Model Download Issues

```bash
# Check init container logs
oc logs -l app=kimi-k2 -c model-downloader -n llm-models

# Common issues:
# 1. Invalid HuggingFace token
# 2. Network connectivity to huggingface.co
# 3. Insufficient storage space
```

### Out of Memory Errors

```bash
# Check pod resource usage
oc adm top pod -l app=kimi-k2 -n llm-models

# Check node resources
oc adm top nodes

# Solutions:
# 1. Reduce MAX_MODEL_LEN in ConfigMap
# 2. Increase GPU_MEMORY_UTILIZATION
# 3. Add more system memory to nodes
```

### GPU Not Detected

```bash
# Check if GPU is allocated to pod
oc describe pod -l app=kimi-k2 -n llm-models | grep nvidia.com/gpu

# Check GPU operator logs
oc logs -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset

# Verify node has GPU
oc get nodes -o json | jq '.items[].status.capacity | select(."nvidia.com/gpu" != null)'
```

## Scaling and Updates

### Update Configuration

```bash
# Edit ConfigMap
oc edit configmap kimi-k2-config -n llm-models

# Restart deployment to apply changes
oc rollout restart deployment kimi-k2-vllm -n llm-models

# Watch rollout status
oc rollout status deployment kimi-k2-vllm -n llm-models
```

### Update Image Version

```bash
# Update to vLLM nightly build
oc set image deployment/kimi-k2-vllm \
  vllm-server=vllm/vllm-openai:nightly \
  -n llm-models

# Watch rollout
oc rollout status deployment kimi-k2-vllm -n llm-models
```

### View Resource Usage

```bash
# Real-time resource monitoring
oc adm top pod -l app=kimi-k2 -n llm-models

# Detailed metrics
oc describe pod -l app=kimi-k2 -n llm-models | grep -A 10 "Limits\|Requests"
```

## Cleanup

### Remove Deployment

```bash
# Delete all resources
oc delete -f manifests/

# Or delete namespace (removes everything)
oc delete namespace llm-models
```

### Verify Cleanup

```bash
# Check namespace is gone
oc get namespace llm-models

# Check PVCs are released (may take time)
oc get pv | grep llm-models
```

## Production Considerations

### 1. High Availability
- For production, consider multiple replicas with different GPU types
- Use horizontal pod autoscaling based on request metrics

### 2. Resource Quotas
```bash
# Set resource quotas for the namespace
oc create quota llm-quota \
  --hard=requests.nvidia.com/gpu=2,limits.nvidia.com/gpu=2 \
  -n llm-models
```

### 3. Monitoring
- Enable ServiceMonitor for Prometheus metrics
- Set up alerts for GPU utilization and API latency
- Monitor model cache disk usage

### 4. Security
- Use NetworkPolicies to restrict traffic
- Enable Pod Security Standards
- Rotate Hugging Face tokens regularly
- Use dedicated service accounts with RBAC

### 5. Backup
```bash
# Backup model cache periodically
oc create job model-backup-$(date +%Y%m%d) \
  --from=cronjob/model-cache-backup \
  -n llm-models
```

## Next Steps

1. Set up monitoring and alerting
2. Configure autoscaling policies
3. Implement API rate limiting
4. Add authentication/authorization
5. Set up model versioning strategy
6. Create backup and disaster recovery plan

## Support and Resources

- vLLM Documentation: https://docs.vllm.ai/
- Kimi K2 Model: https://huggingface.co/moonshotai/Kimi-K2-Instruct
- NVIDIA GPU Operator: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/
- OpenShift Documentation: https://docs.openshift.com/
