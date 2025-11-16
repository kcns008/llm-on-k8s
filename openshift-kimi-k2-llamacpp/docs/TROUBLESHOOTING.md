# Troubleshooting Guide

Common issues and solutions for Kimi K2 llama.cpp deployment on OpenShift.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Init Container Issues](#init-container-issues)
- [Runtime Issues](#runtime-issues)
- [Performance Issues](#performance-issues)
- [Network Issues](#network-issues)
- [GPU Issues](#gpu-issues)
- [Debugging Commands](#debugging-commands)

## Deployment Issues

### Pod Stuck in Pending

**Symptoms:**
```bash
$ oc get pods -n llm-models-llamacpp
NAME                                READY   STATUS    RESTARTS
kimi-k2-llamacpp-xxx               0/1     Pending   0
```

**Causes & Solutions:**

#### 1. No GPU Available

```bash
# Check events
oc describe pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# Look for:
# "0/5 nodes are available: 5 Insufficient nvidia.com/gpu"
```

**Solution:**
```bash
# Verify GPU nodes exist
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU Operator is running
oc get pods -n nvidia-gpu-operator

# If no GPU nodes or operator:
# 1. Add GPU nodes to cluster
# 2. Install NVIDIA GPU Operator from OperatorHub
```

#### 2. PVC Not Bound

```bash
# Check PVC status
oc get pvc -n llm-models-llamacpp
# If STATUS is not "Bound":
```

**Solution:**
```bash
# Check available storage classes
oc get storageclasses

# Edit PVC to use existing storage class
oc edit pvc kimi-k2-gguf-cache -n llm-models-llamacpp
# Add or modify: storageClassName: <your-storage-class>

# Or delete and recreate
oc delete pvc kimi-k2-gguf-cache -n llm-models-llamacpp
# Edit 02-pvc.yaml with correct storageClassName
oc apply -f manifests/02-pvc.yaml
```

#### 3. Resource Limits Too High

```bash
# Check node resources
oc describe node <gpu-node-name> | grep -A 10 "Allocated resources"
```

**Solution:**
```bash
# Reduce resource requests in deployment
oc edit deployment kimi-k2-llamacpp -n llm-models-llamacpp
# Lower memory/cpu requests
```

---

## Init Container Issues

### build-llamacpp Failing

**Symptoms:**
```bash
$ oc get pods -n llm-models-llamacpp
NAME                                READY   STATUS       RESTARTS
kimi-k2-llamacpp-xxx               0/1     Init:Error   0
```

**Check logs:**
```bash
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c build-llamacpp
```

#### Issue: OOMKilled

**Error:** Init container killed due to out of memory

**Solution:**
```bash
# Increase memory limit in deployment
oc edit deployment kimi-k2-llamacpp -n llm-models-llamacpp

# Find build-llamacpp initContainer, increase memory:
# limits:
#   memory: 16Gi  # Increase from 8Gi
```

#### Issue: CMake/Build Errors

**Error:** Build fails with compilation errors

**Solution:**
```bash
# Check if already built
oc exec -n llm-models-llamacpp -it <pod-name> -c llama-server -- \
  ls -la /llamacpp/

# If empty, manually build:
# 1. Increase timeout
# 2. Check CUDA availability in build image
```

---

### model-downloader Failing

**Symptoms:**
```bash
$ oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader
# Shows download errors or timeouts
```

#### Issue: Authentication Failed

**Error:** 401 Unauthorized

**Solution:**
```bash
# Verify HuggingFace token is correct
oc get secret huggingface-token -n llm-models-llamacpp -o yaml

# Delete and recreate with correct token
oc delete secret huggingface-token -n llm-models-llamacpp
oc create secret generic huggingface-token \
  --from-literal=HF_TOKEN=hf_your_correct_token \
  -n llm-models-llamacpp

# Delete pod to retry
oc delete pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp
```

#### Issue: Download Timeout

**Error:** Read timeout, connection reset

**Solution:**
```bash
# Network connectivity issue
# Check egress to huggingface.co
oc run nettest --image=curlimages/curl -it --rm -n llm-models-llamacpp -- \
  curl -I https://huggingface.co

# If fails, check:
# 1. Network policies allowing egress
# 2. Firewall rules
# 3. Proxy configuration
```

#### Issue: Disk Space

**Error:** No space left on device

**Solution:**
```bash
# Check PVC size
oc get pvc kimi-k2-gguf-cache -n llm-models-llamacpp

# If too small, expand PVC (if storage class supports it)
oc edit pvc kimi-k2-gguf-cache -n llm-models-llamacpp
# Increase: storage: 500Gi

# Or delete and recreate with larger size
```

#### Issue: Download Stuck at 90-95%

**Error:** Download appears to hang near completion

**Cause:** huggingface_hub rate limiting or connection issues

**Solution:**
```bash
# Set HF_HUB_ENABLE_HF_TRANSFER=0 in init container
oc edit deployment kimi-k2-llamacpp -n llm-models-llamacpp

# Add to model-downloader env:
# - name: HF_HUB_ENABLE_HF_TRANSFER
#   value: "0"

# Or wait - downloads eventually complete (may take 10+ min pause)
```

---

## Runtime Issues

### Pod Crashes After Init

**Symptoms:**
```bash
$ oc get pods -n llm-models-llamacpp
NAME                                READY   STATUS             RESTARTS
kimi-k2-llamacpp-xxx               0/1     CrashLoopBackOff   5
```

**Check logs:**
```bash
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c llama-server
```

#### Issue: Model File Not Found

**Error:** "Could not find GGUF model file"

**Solution:**
```bash
# Verify model files exist
oc exec -n llm-models-llamacpp -it <pod-name> -c llama-server -- \
  ls -lR /model-cache/

# If empty:
# 1. Check model-downloader logs
# 2. Verify QUANT_TYPE matches downloaded files
# 3. Re-run downloader init container
```

#### Issue: OOMKilled

**Error:** Pod killed due to out of memory

**Solution:**
```bash
# Increase memory limits
oc edit deployment kimi-k2-llamacpp -n llm-models-llamacpp

# For llama-server container:
# limits:
#   memory: 256Gi  # Increase

# Or use smaller quantization
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
# Change QUANT_TYPE to UD-TQ1_0
```

#### Issue: CUDA Error

**Error:** "CUDA error: out of memory"

**Solution:**
```bash
# Ensure MoE offloading is enabled
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp

# Verify:
# MoE_OFFLOAD: ".ffn_.*_exps.=CPU"

# Or reduce N_GPU_LAYERS
# N_GPU_LAYERS: "50"  # Instead of 99

# Restart
oc rollout restart deployment kimi-k2-llamacpp -n llm-models-llamacpp
```

---

## Performance Issues

### Very Slow Inference (<0.5 tok/s)

**Symptoms:** API responds but very slowly

**Debugging:**
```bash
# Check resource usage
oc adm top pod -n llm-models-llamacpp

# Check GPU utilization
GPU_NODE=$(oc get pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp \
  -o jsonpath='{.items[0].spec.nodeName}')
oc debug node/$GPU_NODE -- chroot /host nvidia-smi
```

**Solutions:**

#### 1. Increase CPU Allocation
```bash
oc edit deployment kimi-k2-llamacpp -n llm-models-llamacpp
# Increase cpu limits to match node max
```

#### 2. Reduce MoE Offloading
```bash
# More layers on GPU = faster, but needs more VRAM
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp

# Try partial offloading:
# MoE_OFFLOAD: ".ffn_(up|down)_exps.=CPU"
```

#### 3. Use Faster Storage
```bash
# If using HDD, migrate to SSD
# Change storage class in PVC to SSD-backed class
```

#### 4. Reduce Context Size
```bash
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
# CTX_SIZE: "8192"  # Instead of 16384
```

---

### High Latency (>30s first token)

**Symptoms:** Long wait before first token

**Solutions:**

#### 1. Pre-warm the Model
```bash
# Send a dummy request after deployment
curl https://$ROUTE_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "kimi-k2-thinking", "messages": [{"role": "user", "content": "hi"}]}'
```

#### 2. Increase GPU Layers
```bash
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
# N_GPU_LAYERS: "99"  # Ensure maximum offload
```

---

## Network Issues

### Route Not Accessible

**Symptoms:** 404 or connection refused on route URL

**Debugging:**
```bash
# Check route exists
oc get route kimi-k2-llamacpp -n llm-models-llamacpp

# Check service endpoints
oc get endpoints kimi-k2-llamacpp -n llm-models-llamacpp
# Should show pod IP and port

# Test from inside cluster
oc run curlpod --image=curlimages/curl -it --rm -n llm-models-llamacpp -- \
  curl http://kimi-k2-llamacpp:8001/health
```

**Solutions:**

#### Service Not Ready
```bash
# Wait for pod to be Ready
oc get pods -n llm-models-llamacpp -w

# Check readiness probe
oc describe pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp
# Look at "Readiness" events
```

#### NetworkPolicy Blocking
```bash
# Temporarily remove network policies to test
oc delete networkpolicy -n llm-models-llamacpp --all

# If works, adjust policies in 08-networkpolicy.yaml
```

---

## GPU Issues

### GPU Not Detected

**Symptoms:** llama.cpp falls back to CPU

**Debugging:**
```bash
# Check pod has GPU allocated
oc describe pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp | grep nvidia.com/gpu

# Check GPU visible in container
oc exec -n llm-models-llamacpp -it <pod-name> -c llama-server -- nvidia-smi
```

**Solutions:**

#### GPU Not Requested
```bash
# Verify deployment requests GPU
oc get deployment kimi-k2-llamacpp -n llm-models-llamacpp -o yaml | grep nvidia

# Should show:
# resources:
#   requests:
#     nvidia.com/gpu: "1"
```

#### GPU Operator Not Running
```bash
# Check GPU operator
oc get pods -n nvidia-gpu-operator

# If not found, install from OperatorHub
```

---

## Debugging Commands

### Essential Commands

```bash
# 1. Overall status
oc get all -n llm-models-llamacpp

# 2. Pod details
oc describe pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# 3. All logs
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp --all-containers=true

# 4. Recent events
oc get events -n llm-models-llamacpp --sort-by='.lastTimestamp' | tail -20

# 5. Resource usage
oc adm top pod -n llm-models-llamacpp

# 6. ConfigMap
oc get configmap kimi-k2-llamacpp-config -n llm-models-llamacpp -o yaml

# 7. Secret (redacted)
oc get secret huggingface-token -n llm-models-llamacpp -o yaml
```

### Init Container Logs

```bash
# Build logs
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c build-llamacpp

# Download logs
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader
```

### Main Container Logs

```bash
# Follow server logs
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c llama-server

# Last 100 lines
oc logs --tail=100 -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c llama-server
```

### Interactive Debugging

```bash
# Get shell in running pod
oc exec -n llm-models-llamacpp -it <pod-name> -c llama-server -- /bin/bash

# Check files
ls -lh /model-cache/
ls -lh /llamacpp/

# Test llama.cpp directly
/llamacpp/llama-cli --help
```

### Network Debugging

```bash
# Test internal connectivity
oc run nettest --image=nicolaka/netshoot -it --rm -n llm-models-llamacpp -- bash
# Inside pod:
curl http://kimi-k2-llamacpp:8001/health
nslookup kimi-k2-llamacpp

# Test external
curl -I https://huggingface.co
```

### GPU Debugging

```bash
# SSH to GPU node
GPU_NODE=$(oc get pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp \
  -o jsonpath='{.items[0].spec.nodeName}')
oc debug node/$GPU_NODE

# Check GPU
chroot /host nvidia-smi
chroot /host nvidia-smi -q
```

---

## Getting Help

If issues persist:

1. **Collect diagnostics:**
```bash
# Save all info to file
oc get all -n llm-models-llamacpp > diagnostics.txt
oc describe pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp >> diagnostics.txt
oc logs -n llm-models-llamacpp -l app=kimi-k2-llamacpp --all-containers=true >> diagnostics.txt
oc get events -n llm-models-llamacpp --sort-by='.lastTimestamp' >> diagnostics.txt
```

2. **Check documentation:**
   - [Main README](../README.md)
   - [Model Quantizations](MODEL-QUANTIZATIONS.md)
   - [llama.cpp docs](https://github.com/ggml-org/llama.cpp)
   - [Unsloth Kimi K2 guide](https://docs.unsloth.ai/tutorials/how-to-run/kimi-k2)

3. **Community support:**
   - llama.cpp GitHub Issues
   - OpenShift community forums
   - Unsloth Discord

---

## Common Patterns

### Clean Restart

```bash
# Delete pod, keep everything else
oc delete pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# Full restart
oc rollout restart deployment kimi-k2-llamacpp -n llm-models-llamacpp

# Clean slate (keeps model cache)
oc delete deployment,service,route,configmap,secret -n llm-models-llamacpp --all
oc apply -f manifests/03-configmap.yaml
oc create secret generic huggingface-token --from-literal=HF_TOKEN=xxx -n llm-models-llamacpp
oc apply -f manifests/05-deployment.yaml
oc apply -f manifests/06-service.yaml
oc apply -f manifests/07-route.yaml
```

### Force Re-download Model

```bash
# Delete PVC to clear cache
oc delete pvc kimi-k2-gguf-cache -n llm-models-llamacpp

# Recreate
oc apply -f manifests/02-pvc.yaml

# Delete pod to trigger re-download
oc delete pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp
```

---

**Still stuck?** Double-check [Quickstart Guide](../QUICKSTART.md) for correct deployment steps.
