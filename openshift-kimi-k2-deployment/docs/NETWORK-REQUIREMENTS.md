# Network and Firewall Requirements for Kimi K2 Deployment

This document outlines all network connectivity requirements, firewall rules, and ports that need to be opened for successfully deploying and running the Kimi K2 LLM model on OpenShift.

## Overview

The Kimi K2 deployment requires:
1. **Outbound** internet access for downloading models and container images
2. **Inbound** access for serving API requests (optional, only if exposing externally)
3. **Internal** cluster networking for pod-to-pod and service communication

## Required Outbound Access

### 1. Container Registry Access

The deployment pulls Docker images from public registries.

#### Docker Hub (vLLM Images)
- **Destination**: `registry-1.docker.io` (Docker Hub)
- **Protocol**: HTTPS
- **Port**: 443
- **Purpose**: Download vLLM OpenAI server image
- **Image**: `vllm/vllm-openai:latest` or `vllm/vllm-openai:nightly`
- **Estimated Size**: 5-10 GB
- **Frequency**: Initial deployment + updates

**Firewall Rule:**
```
Source: OpenShift cluster nodes
Destination: registry-1.docker.io (various IPs)
Protocol: TCP
Port: 443
Action: ALLOW
```

**Alternative domains** (Docker Hub CDN):
- `production.cloudflare.docker.com`
- `registry.docker.io`

#### Python Package Index (PyPI)
- **Destination**: `pypi.org`, `files.pythonhosted.org`
- **Protocol**: HTTPS
- **Port**: 443
- **Purpose**: Download Python packages in init container
- **Packages**: `huggingface-hub`, dependencies
- **Estimated Size**: 100-500 MB
- **Frequency**: Initial deployment only

**Firewall Rule:**
```
Source: OpenShift cluster nodes
Destination: pypi.org, files.pythonhosted.org
Protocol: TCP
Port: 443
Action: ALLOW
```

### 2. Hugging Face Model Repository

The critical component - downloading the LLM model weights.

#### Hugging Face Hub
- **Destination**: `huggingface.co`
- **Protocol**: HTTPS
- **Port**: 443
- **Purpose**: Model metadata, repository information
- **Frequency**: Every deployment/restart

**Firewall Rule:**
```
Source: OpenShift cluster nodes
Destination: huggingface.co
Protocol: TCP
Port: 443
Action: ALLOW
```

#### Hugging Face CDN
- **Destination**: `cdn.huggingface.co`, `cdn-lfs.huggingface.co`
- **Protocol**: HTTPS
- **Port**: 443
- **Purpose**: Download model weights (large files)
- **Model Size**: ~250 GB (Kimi K2 Instruct quantized)
- **Bandwidth**: Requires high-bandwidth connection
- **Frequency**: Initial download only (cached on PVC)

**Firewall Rule:**
```
Source: OpenShift cluster nodes
Destination: cdn.huggingface.co, cdn-lfs.huggingface.co
Protocol: TCP
Port: 443
Action: ALLOW
```

**Important Notes:**
- Model download can take 30-60 minutes on 100 Mbps connection
- On 1 Gbps connection: 30-40 minutes
- Uses Git LFS (Large File Storage) protocol over HTTPS
- Supports resume on connection failures
- **Authentication required**: Valid Hugging Face token needed

#### CDN Variations
Hugging Face may use various CDN providers:
- `cdn-lfs.hf.co`
- `s3.amazonaws.com` (specific buckets)
- CloudFlare CDN endpoints

**Recommended**: Allow all HTTPS traffic to `*.huggingface.co`

### 3. DNS Resolution

Required for resolving all external hostnames.

- **Destination**: Your DNS servers (internal or external)
- **Protocol**: DNS (UDP/TCP)
- **Port**: 53
- **Purpose**: Resolve external domain names
- **Domains to resolve**:
  - `huggingface.co`
  - `cdn.huggingface.co`
  - `cdn-lfs.huggingface.co`
  - `registry-1.docker.io`
  - `pypi.org`
  - `files.pythonhosted.org`

**Firewall Rule:**
```
Source: OpenShift cluster nodes
Destination: DNS servers (e.g., 8.8.8.8, 1.1.1.1, or internal)
Protocol: UDP/TCP
Port: 53
Action: ALLOW
```

### 4. NTP (Time Synchronization)

Required for TLS certificate validation.

- **Destination**: NTP servers
- **Protocol**: NTP (UDP)
- **Port**: 123
- **Purpose**: Time synchronization for certificate validation
- **Recommended**: Use internal NTP servers or public pools

**Firewall Rule:**
```
Source: OpenShift cluster nodes
Destination: NTP servers (e.g., pool.ntp.org)
Protocol: UDP
Port: 123
Action: ALLOW
```

## Optional Outbound Access

### 1. Monitoring and Telemetry

If using external monitoring solutions:

- **Prometheus Remote Write**: TCP 443 to external Prometheus
- **Grafana Cloud**: TCP 443 to `grafana.net`
- **Datadog**: TCP 443 to `datadoghq.com`

### 2. Log Aggregation

If using external logging:

- **Elasticsearch**: TCP 9200/9300
- **Splunk**: TCP 8088 (HEC)
- **CloudWatch**: TCP 443 to `logs.amazonaws.com`

## Required Inbound Access

### 1. External API Access (via OpenShift Route)

If exposing the API externally through OpenShift Route:

- **Source**: External clients (internet or corporate network)
- **Destination**: OpenShift Router (Load Balancer IP)
- **Protocol**: HTTPS
- **Port**: 443
- **Purpose**: External API requests to Kimi K2 model
- **Path**: Route hostname (e.g., `kimi-k2-vllm-llm-models.apps.cluster.com`)

**Firewall Rule (External Firewall):**
```
Source: Authorized client networks
Destination: OpenShift Ingress/Router IP
Protocol: TCP
Port: 443
Action: ALLOW
```

**OpenShift Route Configuration:**
- Route uses Edge TLS termination
- Backend communication is HTTP (within cluster)
- Router handles SSL/TLS

### 2. OpenShift API Access (for Management)

For administrators to manage the deployment:

- **Destination**: OpenShift API server
- **Protocol**: HTTPS
- **Port**: 6443 (default)
- **Purpose**: `oc` CLI and web console access

**Firewall Rule:**
```
Source: Administrator workstations
Destination: OpenShift API server
Protocol: TCP
Port: 6443
Action: ALLOW
```

### 3. OpenShift Web Console

For dashboard access:

- **Destination**: OpenShift Console Route
- **Protocol**: HTTPS
- **Port**: 443
- **Purpose**: Web-based management

## Internal Cluster Networking

These are handled automatically by OpenShift SDN/OVN, but listed for completeness.

### 1. Pod-to-Pod Communication

- **Source**: Any pod in cluster
- **Destination**: Kimi K2 pod
- **Protocol**: TCP
- **Port**: 8000
- **Purpose**: Internal API requests
- **Network**: OpenShift SDN/OVN (overlay network)

**Note**: NetworkPolicy (if applied) restricts this to authorized namespaces only.

### 2. Service Discovery (DNS)

- **Source**: Pods
- **Destination**: OpenShift DNS (CoreDNS)
- **Protocol**: UDP/TCP
- **Port**: 53
- **Purpose**: Resolve service names like `kimi-k2-vllm.llm-models.svc.cluster.local`

### 3. OpenShift Router to Service

- **Source**: OpenShift Router pods
- **Destination**: kimi-k2-vllm service
- **Protocol**: HTTP
- **Port**: 8000
- **Purpose**: Route external traffic to backend pods

## Network Bandwidth Requirements

### Initial Deployment

**Model Download:**
- **Data Transfer**: ~250 GB (one-time)
- **Recommended Bandwidth**: 100 Mbps minimum, 1 Gbps preferred
- **Duration**:
  - 100 Mbps: ~5-6 hours
  - 1 Gbps: ~30-40 minutes
  - 10 Gbps: ~3-5 minutes

**Container Images:**
- **Data Transfer**: ~5-10 GB (one-time, cached on nodes)
- **Duration**: 5-15 minutes on 100 Mbps

### Steady State

**Ongoing Traffic:**
- API requests: Low bandwidth (< 1 Mbps per active client)
- Model responses: Variable (depends on token count)
- Estimated: 10-50 Mbps for typical usage

## Proxy Configuration

If your OpenShift cluster uses HTTP proxy for outbound connections:

### 1. Configure Cluster-Wide Proxy

Edit cluster proxy configuration:

```bash
oc edit proxy/cluster
```

Add:
```yaml
spec:
  httpProxy: http://proxy.example.com:8080
  httpsProxy: http://proxy.example.com:8080
  noProxy: .cluster.local,.svc,10.0.0.0/8,172.30.0.0/16
```

### 2. Configure Deployment to Use Proxy

Add environment variables to deployment:

```yaml
env:
  - name: HTTP_PROXY
    value: "http://proxy.example.com:8080"
  - name: HTTPS_PROXY
    value: "http://proxy.example.com:8080"
  - name: NO_PROXY
    value: "localhost,127.0.0.1,.cluster.local,.svc"
```

### 3. Proxy Bypass for Internal Services

Ensure `NO_PROXY` includes:
- `.cluster.local` - Internal Kubernetes services
- `.svc` - Service discovery
- Pod/Service CIDR ranges
- OpenShift internal IPs

## Firewall Configuration Examples

### IPTables Example (Linux Firewall)

```bash
# Allow outbound HTTPS to Hugging Face
iptables -A OUTPUT -p tcp -d cdn.huggingface.co --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d cdn-lfs.huggingface.co --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d huggingface.co --dport 443 -j ACCEPT

# Allow outbound HTTPS to Docker Hub
iptables -A OUTPUT -p tcp -d registry-1.docker.io --dport 443 -j ACCEPT

# Allow outbound HTTPS to PyPI
iptables -A OUTPUT -p tcp -d pypi.org --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d files.pythonhosted.org --dport 443 -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow inbound HTTPS to OpenShift Router
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

### Cisco ASA Example

```
! Allow outbound HTTPS to Hugging Face
access-list OUTSIDE_IN extended permit tcp any host cdn.huggingface.co eq 443
access-list OUTSIDE_IN extended permit tcp any host cdn-lfs.huggingface.co eq 443

! Allow outbound to Docker Hub
access-list OUTSIDE_IN extended permit tcp any host registry-1.docker.io eq 443

! Apply to interface
access-group OUTSIDE_IN in interface outside
```

### Palo Alto Firewall Example

**Security Policy:**
- **Name**: Allow-HuggingFace-CDN
- **Source**: OpenShift-Cluster-Zone
- **Destination**: External
- **Application**: ssl, web-browsing
- **Service**: application-default
- **URL Category**: Create custom category for:
  - `*.huggingface.co`
  - `registry-1.docker.io`
  - `pypi.org`
- **Action**: Allow

## Network Security Groups (Cloud Environments)

### AWS Security Groups

**Outbound Rules:**
```
Type: HTTPS
Protocol: TCP
Port: 443
Destination: 0.0.0.0/0
Description: Allow HTTPS for model download and image pull

Type: DNS
Protocol: UDP
Port: 53
Destination: 0.0.0.0/0
Description: Allow DNS resolution
```

**Inbound Rules:**
```
Type: HTTPS
Protocol: TCP
Port: 443
Source: ALB Security Group
Description: Allow traffic from Application Load Balancer
```

### Azure Network Security Group

**Outbound Rules:**
```json
{
  "name": "Allow-HTTPS-Outbound",
  "properties": {
    "protocol": "TCP",
    "sourcePortRange": "*",
    "destinationPortRange": "443",
    "sourceAddressPrefix": "VirtualNetwork",
    "destinationAddressPrefix": "Internet",
    "access": "Allow",
    "priority": 100,
    "direction": "Outbound"
  }
}
```

### GCP Firewall Rules

```bash
# Allow outbound HTTPS
gcloud compute firewall-rules create allow-https-outbound \
  --direction=EGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:443 \
  --destination-ranges=0.0.0.0/0

# Allow inbound HTTPS to load balancer
gcloud compute firewall-rules create allow-https-inbound \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=openshift-router
```

## SSL/TLS Certificate Requirements

### OpenShift Router Certificates

- **Default**: OpenShift generates self-signed certificates
- **Production**: Use valid CA-signed certificates
- **Wildcard**: Recommended for `*.apps.cluster.example.com`

**Install custom certificate:**
```bash
oc create secret tls custom-certs \
  --cert=fullchain.pem \
  --key=privkey.pem \
  -n openshift-ingress

oc patch ingresscontroller/default \
  -n openshift-ingress-operator \
  --type=merge \
  -p '{"spec":{"defaultCertificate":{"name":"custom-certs"}}}'
```

### Hugging Face HTTPS

- **Certificates**: Managed by Hugging Face
- **Validation**: Python `requests` library validates by default
- **Custom CA**: If using corporate CA, add to container:

```yaml
volumeMounts:
  - name: ca-bundle
    mountPath: /etc/ssl/certs/ca-bundle.crt
    subPath: ca-bundle.crt
volumes:
  - name: ca-bundle
    configMap:
      name: custom-ca-bundle
```

## Testing Network Connectivity

### From OpenShift Node

```bash
# SSH to OpenShift node or use debug pod
oc debug node/worker-0

# Test Hugging Face connectivity
curl -I https://huggingface.co
curl -I https://cdn.huggingface.co

# Test Docker Hub
curl -I https://registry-1.docker.io/v2/

# Test PyPI
curl -I https://pypi.org

# Test DNS resolution
nslookup huggingface.co
dig cdn-lfs.huggingface.co

# Test bandwidth
wget -O /dev/null https://cdn.huggingface.co/test-file
```

### From Pod

Create a test pod:

```bash
oc run nettest --image=nicolaka/netshoot -it --rm -- /bin/bash

# Inside pod:
curl -I https://huggingface.co
curl -I https://cdn.huggingface.co
nslookup huggingface.co
traceroute huggingface.co
```

### Test Model Download

```bash
# Create test pod with HuggingFace hub
oc run hf-test --image=python:3.11 -it --rm -- /bin/bash

# Inside pod:
pip install huggingface-hub
python3 -c "
from huggingface_hub import hf_hub_download
hf_hub_download(repo_id='gpt2', filename='config.json', token='YOUR_TOKEN')
"
```

## Troubleshooting Network Issues

### Issue: Cannot Reach Hugging Face

**Symptoms:**
- Init container fails with connection timeout
- Error: `Failed to connect to huggingface.co`

**Solutions:**
1. Check DNS resolution:
   ```bash
   nslookup huggingface.co
   ```
2. Test HTTPS connectivity:
   ```bash
   curl -v https://huggingface.co
   ```
3. Check proxy settings:
   ```bash
   echo $HTTP_PROXY
   echo $HTTPS_PROXY
   ```
4. Verify firewall rules allow outbound HTTPS

### Issue: Slow Model Download

**Symptoms:**
- Init container runs for hours
- Model download progress is very slow

**Solutions:**
1. Check bandwidth:
   ```bash
   iperf3 -c cdn.huggingface.co
   ```
2. Check for throttling or QoS policies
3. Try during off-peak hours
4. Consider downloading model separately and loading from NFS/S3

### Issue: Cannot Access API Route

**Symptoms:**
- Route URL returns 503 Service Unavailable
- Connection timeout to route

**Solutions:**
1. Check pod is ready:
   ```bash
   oc get pods -l app=kimi-k2
   ```
2. Check service endpoints:
   ```bash
   oc get endpoints kimi-k2-vllm
   ```
3. Test from inside cluster:
   ```bash
   oc run curl --image=curlimages/curl -it --rm -- \
     curl http://kimi-k2-vllm.llm-models.svc.cluster.local:8000/health
   ```
4. Check router logs:
   ```bash
   oc logs -n openshift-ingress -l app=router
   ```

## Bandwidth Estimation

### Monthly Bandwidth (Steady State)

**Assumptions:**
- 1000 API requests/day
- Average response: 500 tokens (~2KB)
- Logging and monitoring: 1 GB/day

**Calculation:**
```
API traffic: 1000 requests × 2 KB × 30 days = 60 MB/month
Monitoring: 1 GB/day × 30 days = 30 GB/month
Total: ~30 GB/month
```

### Initial Deployment Bandwidth

**One-time:**
- Model download: 250 GB
- Container images: 10 GB
- Python packages: 0.5 GB
- **Total**: ~260 GB

## Summary Checklist

### Required Firewall Rules

- [ ] Allow outbound HTTPS (443) to `huggingface.co`
- [ ] Allow outbound HTTPS (443) to `cdn.huggingface.co`
- [ ] Allow outbound HTTPS (443) to `cdn-lfs.huggingface.co`
- [ ] Allow outbound HTTPS (443) to `registry-1.docker.io`
- [ ] Allow outbound HTTPS (443) to `pypi.org`
- [ ] Allow outbound HTTPS (443) to `files.pythonhosted.org`
- [ ] Allow outbound DNS (53 UDP/TCP)
- [ ] Allow inbound HTTPS (443) to OpenShift Router (if external access needed)

### Required Configuration

- [ ] DNS resolution for external domains
- [ ] NTP synchronization
- [ ] Proxy configuration (if applicable)
- [ ] Valid Hugging Face token
- [ ] SSL certificates for route (production)

### Network Testing

- [ ] Test connectivity to Hugging Face
- [ ] Test connectivity to Docker Hub
- [ ] Test DNS resolution
- [ ] Test bandwidth to CDN
- [ ] Test internal cluster networking
- [ ] Test external route access

### Bandwidth Planning

- [ ] Provision for 250 GB initial download
- [ ] Plan for 30-60 minute download window
- [ ] Allocate 30-50 GB/month for steady state
- [ ] Consider network costs (cloud egress)

## Contact for Network Issues

If you encounter network issues:

1. Check logs: `oc logs -l app=kimi-k2 --all-containers=true`
2. Verify firewall rules against this document
3. Test connectivity using methods in "Testing Network Connectivity"
4. Contact your network/security team with specific error messages
5. Review OpenShift network policies: `oc get networkpolicies`

## Additional Resources

- **Hugging Face Hub API**: https://huggingface.co/docs/hub/api
- **OpenShift Networking**: https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html
- **vLLM Documentation**: https://docs.vllm.ai/en/latest/
- **NVIDIA GPU Operator**: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/
