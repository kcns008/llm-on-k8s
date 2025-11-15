# Kimi K2 Deployment Guide - OpenShift Web Console

This guide explains how to deploy the Kimi K2 LLM model on OpenShift using the Web Console (Dashboard).

## Prerequisites

- Access to OpenShift Web Console
- Cluster with GPU-enabled nodes (NVIDIA Tesla T4 or better)
- Hugging Face token from: https://huggingface.co/settings/tokens
- All manifest files from `openshift-kimi-k2-deployment/manifests/`

## Step-by-Step Deployment

### Step 1: Access OpenShift Web Console

1. Open your web browser
2. Navigate to your OpenShift cluster URL (e.g., `https://console-openshift-console.apps.your-cluster.com`)
3. Log in with your credentials
4. You should see the OpenShift dashboard

### Step 2: Create a New Project (Namespace)

#### Method A: Using the UI

1. Click on **Home** → **Projects** in the left sidebar
2. Click **Create Project** button (top right)
3. Fill in the form:
   - **Name**: `llm-models`
   - **Display Name**: `LLM Models`
   - **Description**: `Namespace for running open-source LLM models`
4. Click **Create**

#### Method B: Using YAML Import

1. Click **+** (Import YAML) in the top navigation bar
2. Copy and paste the contents of `manifests/01-namespace.yaml`
3. Click **Create**
4. Wait for confirmation message

### Step 3: Switch to the Project

1. Click the **Project** dropdown in the top bar
2. Select **llm-models** from the list
3. Verify you're in the correct project (shown in top bar)

### Step 4: Create Persistent Volume Claims

1. Navigate to **Storage** → **PersistentVolumeClaims** in the left sidebar
2. Click **Create PersistentVolumeClaim** button

#### Create First PVC (Model Cache)

3. Switch to **YAML view** (toggle in top right)
4. Copy and paste the first PVC from `manifests/02-pvc.yaml` (kimi-k2-model-cache)
5. Click **Create**
6. Wait for Status to change to **Bound**

#### Create Second PVC (Shared Memory)

7. Click **Create PersistentVolumeClaim** again
8. Switch to **YAML view**
9. Copy and paste the second PVC from `manifests/02-pvc.yaml` (kimi-k2-shm)
10. Click **Create**

**Verification:**
- Both PVCs should show Status: **Bound**
- kimi-k2-model-cache: 300Gi
- kimi-k2-shm: 10Gi

### Step 5: Create ConfigMap

1. Navigate to **Workloads** → **ConfigMaps**
2. Click **Create ConfigMap** button
3. Switch to **YAML view**
4. Copy and paste contents from `manifests/03-configmap.yaml`
5. Click **Create**

**Verification:**
- ConfigMap **kimi-k2-config** appears in the list
- Click on it to verify all key-value pairs are present

### Step 6: Create Hugging Face Secret

1. Navigate to **Workloads** → **Secrets**
2. Click **Create** → **Key/value secret**

#### Fill in the form:
- **Secret name**: `huggingface-token`
- **Key**: `HF_TOKEN`
- **Value**: Your actual Hugging Face token (paste it here)
  - Get token from: https://huggingface.co/settings/tokens

3. Click **Create**

**Important:** Keep this token secure! It allows downloading models from Hugging Face.

**Verification:**
- Secret **huggingface-token** appears in the list
- Type should be **Opaque**
- Size should be **1** (one key)

### Step 7: Deploy Kimi K2 vLLM Server

1. Navigate to **Workloads** → **Deployments**
2. Click **Create Deployment** button
3. Switch to **YAML view**
4. Copy and paste contents from `manifests/05-deployment.yaml`
5. Click **Create**

#### Monitor Deployment Progress

6. You'll be redirected to the deployment details page
7. Click on **Pods** tab to see pod status
8. Pod will show status progression:
   - **Pending** → Waiting for resources
   - **Init:0/1** → Downloading model (30-60 minutes)
   - **Running** → Model loaded, server starting
   - **Ready** → Server is ready to serve requests

#### View Logs

9. Click on the pod name (e.g., `kimi-k2-vllm-xxxxx-xxxxx`)
10. Click **Logs** tab
11. Select container from dropdown:
    - **model-downloader** - View model download progress
    - **vllm-server** - View server startup and runtime logs

**Expected Timeline:**
- Model download: 30-60 minutes (depending on network speed)
- Server startup: 5-10 minutes
- Total time to Ready: 35-70 minutes

### Step 8: Create Service

1. Navigate to **Networking** → **Services**
2. Click **Create Service** button
3. Switch to **YAML view**
4. Copy and paste contents from `manifests/06-service.yaml`
5. Click **Create**

**Verification:**
- Service **kimi-k2-vllm** appears in the list
- Type: **ClusterIP**
- Port: **8000**
- Target Pod: Should show **1** pod(s)

### Step 9: Create Route (External Access)

1. Navigate to **Networking** → **Routes**
2. Click **Create Route** button

#### Option A: Using Form View

3. Fill in the form:
   - **Name**: `kimi-k2-vllm`
   - **Service**: Select `kimi-k2-vllm` from dropdown
   - **Target port**: `8000 → 8000 (TCP)`
   - **Secure Route**: Check this box
   - **TLS Termination**: Select **Edge**
   - **Insecure Traffic**: Select **Redirect**

4. Click **Create**

#### Option B: Using YAML View

3. Switch to **YAML view**
4. Copy and paste contents from `manifests/07-route.yaml`
5. Click **Create**

**Get the Route URL:**
6. After creation, you'll see the route details
7. Copy the **Location** URL (e.g., `https://kimi-k2-vllm-llm-models.apps.your-cluster.com`)
8. Save this URL - you'll use it to access the API

### Step 10: Create Network Policy (Optional but Recommended)

1. Navigate to **Networking** → **NetworkPolicies**
2. Click **Create NetworkPolicy** button
3. Switch to **YAML view**
4. Copy and paste contents from `manifests/08-networkpolicy.yaml`
5. Click **Create**

**This provides:**
- Ingress rules: Only allow traffic from OpenShift router and same namespace
- Egress rules: Allow DNS, HTTP/HTTPS for downloading models

### Step 11: Create Service Monitor (Optional - for Prometheus)

**Note:** Only create this if you have OpenShift monitoring enabled.

1. Navigate to **Monitoring** → **Alerting** (or search for ServiceMonitor)
2. Click **+** (Import YAML) in top navigation
3. Copy and paste contents from `manifests/09-servicemonitor.yaml`
4. Click **Create**

**This enables:**
- Prometheus metrics collection
- Grafana dashboards
- Custom alerts based on metrics

## Verification and Testing

### Step 1: Verify All Resources Are Ready

1. Navigate to **Workloads** → **Deployments**
2. Check that **kimi-k2-vllm** shows:
   - **Status**: ✓ (green checkmark)
   - **Pods**: 1/1 Ready

3. Navigate to **Workloads** → **Pods**
4. Check pod status:
   - **Status**: Running
   - **Ready**: 1/1
   - **Restarts**: 0 (or low number)

### Step 2: Check Pod Logs

1. Click on the pod name
2. Click **Logs** tab
3. Select **vllm-server** container
4. Look for messages like:
   ```
   INFO: Started server process
   INFO: Waiting for application startup
   INFO: Application startup complete
   INFO: Uvicorn running on http://0.0.0.0:8000
   ```

### Step 3: Test Health Endpoint

1. Navigate to **Networking** → **Routes**
2. Copy the route URL (Location field)
3. Open a new browser tab or use terminal:

```bash
# Replace with your actual route URL
curl https://kimi-k2-vllm-llm-models.apps.your-cluster.com/health
```

Expected response:
```json
{"status": "ok"}
```

### Step 4: Test Model API

#### Using Web Console Terminal

1. Click **>_** (Terminal) in the top navigation bar
2. This opens a terminal in your browser
3. Run test commands:

```bash
# Set your route URL
export KIMI_URL="https://kimi-k2-vllm-llm-models.apps.your-cluster.com"

# List models
curl $KIMI_URL/v1/models

# Test completion
curl $KIMI_URL/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2",
    "prompt": "Explain AI in simple terms:",
    "max_tokens": 100
  }'
```

#### Using Browser (for simple GET requests)

1. Open route URL in browser: `https://your-route-url/health`
2. You should see health status
3. Try: `https://your-route-url/v1/models`

### Step 5: Monitor Resource Usage

1. Navigate to **Observe** → **Dashboards**
2. Select **Kubernetes / Compute Resources / Workload**
3. Filter by:
   - **Namespace**: llm-models
   - **Workload**: kimi-k2-vllm

**Monitor:**
- CPU usage
- Memory usage
- GPU utilization (if GPU metrics are available)
- Network I/O

## Troubleshooting

### Pod Stuck in Pending

**Symptoms:** Pod shows **Pending** status for a long time

**Steps:**
1. Click on the pod name
2. Click **Events** tab
3. Look for error messages

**Common Issues:**
- **"Insufficient nvidia.com/gpu"** - No GPU available
  - Solution: Check GPU nodes are ready, install GPU operator
- **"PVC not bound"** - Storage issues
  - Solution: Check PVC status, verify storage class exists

### Init Container Failing

**Symptoms:** Pod shows **Init:Error** or **Init:CrashLoopBackOff**

**Steps:**
1. Click on the pod name
2. Click **Logs** tab
3. Select **model-downloader** from container dropdown
4. Check logs for errors

**Common Issues:**
- **Authentication failed** - Invalid HuggingFace token
  - Solution: Update secret with correct token
- **Network timeout** - Cannot reach huggingface.co
  - Solution: Check firewall rules, proxy settings
- **Disk full** - Insufficient storage
  - Solution: Increase PVC size, check storage quota

### Pod Running but Not Ready

**Symptoms:** Pod shows **Running** but **0/1** Ready

**Steps:**
1. Click on the pod name
2. Click **Logs** tab
3. Select **vllm-server** container
4. Look for errors

**Common Issues:**
- **OOM (Out of Memory)** - Not enough RAM/VRAM
  - Solution: Reduce MAX_MODEL_LEN in ConfigMap, increase memory limits
- **CUDA errors** - GPU issues
  - Solution: Check GPU operator logs, verify GPU is healthy
- **Model loading failed** - Corrupt download
  - Solution: Delete pod to retry download

### Route Not Accessible

**Symptoms:** Cannot access route URL, connection timeout

**Steps:**
1. Navigate to **Networking** → **Routes**
2. Click on **kimi-k2-vllm** route
3. Check **Conditions** section

**Common Issues:**
- **Service not ready** - Backend pods not ready
  - Solution: Wait for pods to be ready, check pod logs
- **TLS errors** - Certificate issues
  - Solution: Check route TLS settings, use edge termination
- **Firewall blocking** - External firewall rules
  - Solution: Check firewall, add route host to allowlist

### Viewing Events

1. Navigate to **Home** → **Events**
2. Filter by **Namespace**: llm-models
3. Look for **Warning** or **Error** events
4. Check timestamps to find recent issues

### Checking Resource Limits

1. Navigate to **Workloads** → **Deployments**
2. Click **kimi-k2-vllm**
3. Click **YAML** tab
4. Search for `resources:` section
5. Verify:
   - GPU request: 1
   - Memory limits: 64Gi
   - CPU requests: 4

## Scaling and Configuration Updates

### Update Configuration (ConfigMap)

1. Navigate to **Workloads** → **ConfigMaps**
2. Click **kimi-k2-config**
3. Click **Actions** → **Edit ConfigMap**
4. Modify values as needed (e.g., MAX_MODEL_LEN)
5. Click **Save**
6. Restart deployment:
   - Navigate to **Workloads** → **Deployments**
   - Click **kimi-k2-vllm**
   - Click **Actions** → **Restart rollout**

### Update Image Version

1. Navigate to **Workloads** → **Deployments**
2. Click **kimi-k2-vllm**
3. Click **YAML** tab
4. Find `image:` line (search for "vllm/vllm-openai")
5. Change tag (e.g., `latest` to `nightly`)
6. Click **Save**
7. Deployment will automatically roll out new version

### Adjust Resource Limits

1. Navigate to **Workloads** → **Deployments**
2. Click **kimi-k2-vllm**
3. Click **YAML** tab
4. Find `resources:` section
5. Modify values:
   ```yaml
   resources:
     requests:
       nvidia.com/gpu: 1
       memory: 32Gi
       cpu: 4
     limits:
       nvidia.com/gpu: 1
       memory: 64Gi  # Increase if OOM errors
       cpu: 8
   ```
6. Click **Save**

## Monitoring and Observability

### View Pod Metrics

1. Navigate to **Workloads** → **Pods**
2. Click on pod name
3. Click **Metrics** tab
4. View:
   - CPU usage over time
   - Memory usage over time
   - Network I/O

### View Logs in Real-time

1. Navigate to **Workloads** → **Pods**
2. Click on pod name
3. Click **Logs** tab
4. Enable **Follow** toggle (top right)
5. Logs will auto-update as new entries arrive

### Set Up Alerts (if Prometheus enabled)

1. Navigate to **Observe** → **Alerting**
2. Click **Create** → **Alerting Rule**
3. Define alert conditions:
   - **Alert Name**: `KimiK2HighMemory`
   - **Expression**: `container_memory_usage_bytes{pod=~"kimi-k2.*"} > 60000000000`
   - **Duration**: `5m`
4. Save alert rule

### View Dashboards

1. Navigate to **Observe** → **Dashboards**
2. Select pre-built dashboards:
   - **Kubernetes / Compute Resources / Namespace (Pods)**
   - **Kubernetes / Compute Resources / Pod**
3. Filter by namespace: **llm-models**

## Cleanup

### Delete All Resources

#### Method 1: Delete Entire Project

1. Navigate to **Home** → **Projects**
2. Click **⋮** (three dots) next to **llm-models**
3. Click **Delete Project**
4. Type `llm-models` to confirm
5. Click **Delete**

**Warning:** This deletes EVERYTHING in the namespace, including PVCs!

#### Method 2: Delete Individual Resources

1. Navigate to each resource type:
   - **Networking** → **Routes** → Delete route
   - **Networking** → **Services** → Delete service
   - **Workloads** → **Deployments** → Delete deployment
   - **Workloads** → **ConfigMaps** → Delete configmap
   - **Workloads** → **Secrets** → Delete secret
   - **Storage** → **PersistentVolumeClaims** → Delete PVCs

2. For each resource:
   - Click **⋮** (three dots) next to resource name
   - Click **Delete**
   - Confirm deletion

### Verify Cleanup

1. Navigate to **Home** → **Projects**
2. Verify **llm-models** is gone (if you deleted the project)
3. Or navigate to **Storage** → **PersistentVolumes**
4. Verify no PVs are still bound to **llm-models** namespace

## Best Practices

### 1. Resource Management
- Start with conservative resource limits
- Monitor actual usage for 1-2 days
- Adjust limits based on real usage patterns

### 2. Security
- Rotate Hugging Face token regularly
- Use NetworkPolicies to restrict traffic
- Enable Pod Security Standards
- Use dedicated service accounts

### 3. Monitoring
- Enable Prometheus ServiceMonitor
- Set up alerts for:
  - High memory usage (> 80%)
  - Pod restarts
  - API error rates
- Review logs daily

### 4. Updates
- Test new vLLM versions in dev environment first
- Use `nightly` tag only for testing
- Pin specific versions for production (e.g., `v0.5.0`)
- Take PVC snapshots before major updates

### 5. Cost Optimization
- Use spot/preemptible GPU nodes if available
- Scale down to 0 replicas during off-hours
- Monitor GPU utilization - aim for > 60%
- Consider smaller quantized models for dev/test

## Next Steps

1. **Set Up Authentication**
   - Add OAuth proxy for API access
   - Implement API key management
   - Configure RBAC for team access

2. **Implement Rate Limiting**
   - Use OpenShift Service Mesh
   - Configure request quotas
   - Set up fair queuing

3. **Enable Autoscaling**
   - Create HorizontalPodAutoscaler
   - Set up custom metrics (requests/sec)
   - Configure min/max replicas

4. **Backup Strategy**
   - Schedule PVC snapshots
   - Export model cache to object storage
   - Document restore procedures

5. **Multi-Model Deployment**
   - Deploy additional LLM models
   - Set up model routing/selection
   - Implement A/B testing

## Support Resources

- **vLLM Documentation**: https://docs.vllm.ai/
- **OpenShift Docs**: https://docs.openshift.com/
- **Kimi K2 Model**: https://huggingface.co/moonshotai/Kimi-K2-Instruct
- **GPU Operator**: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/

## Common Questions

**Q: How long does initial deployment take?**
A: 35-70 minutes (30-60 min for model download + 5-10 min for server startup)

**Q: Can I use multiple GPUs?**
A: Yes, increase `TENSOR_PARALLEL_SIZE` in ConfigMap and GPU requests in Deployment

**Q: What if I don't have Tesla T4?**
A: Any NVIDIA GPU with 16GB+ VRAM works. For smaller GPUs, use more aggressive quantization.

**Q: Can I deploy multiple models?**
A: Yes, create separate deployments with different MODEL_NAME in ConfigMap.

**Q: How do I update the model?**
A: Change MODEL_NAME in ConfigMap, delete PVC to clear cache, restart deployment.

**Q: Is this production-ready?**
A: This is a starting point. Add authentication, monitoring, backups, and HA for production.
