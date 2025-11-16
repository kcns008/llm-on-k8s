# Understanding GGUF Quantizations for Kimi K2

Complete guide to choosing the right quantization level for your deployment.

## What is Quantization?

**Quantization** reduces model size by using fewer bits to represent weights:
- **Full precision (BF16)**: ~1TB, extremely slow on consumer GPUs
- **Quantized (1-5 bit)**: 247GB-732GB, practical for single GPUs

**Benefits:**
- ✅ Smaller disk space and memory requirements
- ✅ Faster loading times
- ✅ Runs on consumer/edge GPUs (Tesla T4)
- ✅ Minimal quality loss with modern quantization (Unsloth Dynamic)

**Tradeoffs:**
- ⚠️ Slight accuracy reduction (usually <2%)
- ⚠️ Some quantizations may show minor quality degradation

## Unsloth Dynamic Quantization

Unsloth's **Dynamic 2.0** quantization achieves:
- **SOTA performance** on Aider Polyglot coding benchmark
- **SOTA performance** on 5-shot MMLU knowledge test
- **Better than static quantization** at same bit levels

All models in `unsloth/Kimi-K2-Thinking-GGUF` and `unsloth/Kimi-K2-Instruct-GGUF` use this technology.

## Available Quantizations

### UD-TQ1_0 (1.8-bit)

**Best for:** Maximum efficiency, minimal VRAM

| Metric | Value |
|--------|-------|
| **Size** | 245 GB |
| **Effective bits** | 1.92/1.56 bit (MoE/non-MoE) |
| **VRAM w/ offload** | ~8 GB |
| **RAM needed** | 64+ GB |
| **Quality** | Good (suitable for most tasks) |
| **Speed on T4** | ~2 tok/s |

**Use cases:**
- Cost-sensitive deployments
- Edge/on-premise with limited GPU
- Experimentation and development
- Non-critical applications

**ConfigMap:**
```yaml
QUANT_TYPE: "UD-TQ1_0"
```

---

### UD-IQ1_S (1.78-bit)

**Best for:** Slightly better quality than TQ1_0

| Metric | Value |
|--------|-------|
| **Size** | 281 GB |
| **Effective bits** | 2.06/1.56 bit |
| **VRAM w/ offload** | ~9 GB |
| **RAM needed** | 64+ GB |
| **Quality** | Better than TQ1_0 |
| **Speed on T4** | ~1.8 tok/s |

**ConfigMap:**
```yaml
QUANT_TYPE: "UD-IQ1_S"
```

---

### UD-Q2_K_XL (2.71-bit) ⭐ **RECOMMENDED**

**Best for:** Balanced quality and performance

| Metric | Value |
|--------|-------|
| **Size** | 381 GB |
| **Effective bits** | 3.5/2.5 bit |
| **VRAM w/ offload** | ~12 GB |
| **RAM needed** | 96+ GB |
| **Quality** | Excellent (near full precision) |
| **Speed on T4** | ~1.5 tok/s |

⭐ **Recommended by Unsloth** for best balance

**Use cases:**
- Production deployments
- Quality-sensitive applications
- When you have 96GB+ RAM available
- General-purpose inference

**ConfigMap:**
```yaml
QUANT_TYPE: "UD-Q2_K_XL"
```

---

### UD-IQ3_XXS (3.12-bit)

**Best for:** Higher quality, moderate size

| Metric | Value |
|--------|-------|
| **Size** | 417 GB |
| **Effective bits** | 3.5/2.06 bit |
| **VRAM w/ offload** | ~13 GB |
| **RAM needed** | 128+ GB |
| **Quality** | Very good |
| **Speed on T4** | ~1.3 tok/s |

**ConfigMap:**
```yaml
QUANT_TYPE: "UD-IQ3_XXS"
```

---

### UD-Q4_K_XL (4.5-bit)

**Best for:** Maximum quality, if you have resources

| Metric | Value |
|--------|-------|
| **Size** | 588 GB |
| **Effective bits** | 5.5/4.5 bit |
| **VRAM w/ offload** | ~18 GB (needs A10/V100) |
| **RAM needed** | 192+ GB |
| **Quality** | Near full precision |
| **Speed on A10** | ~3 tok/s |

**Use cases:**
- Research and development
- Maximum quality requirements
- GPU: A10, V100, or better

**ConfigMap:**
```yaml
QUANT_TYPE: "UD-Q4_K_XL"
```

---

### UD-Q5_K_XL (5.5-bit)

**Best for:** When quality is paramount

| Metric | Value |
|--------|-------|
| **Size** | 732 GB |
| **Effective bits** | 6.5/5.5 bit |
| **VRAM w/ offload** | ~23 GB (needs A10G/A100) |
| **RAM needed** | 256+ GB |
| **Quality** | Essentially full precision |
| **Speed on A10G** | ~4 tok/s |

**ConfigMap:**
```yaml
QUANT_TYPE: "UD-Q5_K_XL"
```

## Comparison Table

| Quant | Size | T4 Compatible | RAM | Quality | Speed | Use Case |
|-------|------|---------------|-----|---------|-------|----------|
| TQ1_0 | 245GB | ✅ Yes | 64GB | Good | Fastest | Dev/testing |
| IQ1_S | 281GB | ✅ Yes | 64GB | Better | Fast | Edge deployments |
| **Q2_K_XL** | **381GB** | ✅ Yes | **96GB** | **Excellent** | **Medium** | **Production** |
| IQ3_XXS | 417GB | ⚠️ Tight fit | 128GB | Very good | Medium | Quality-focused |
| Q4_K_XL | 588GB | ❌ No (18GB) | 192GB | Near-perfect | Slower | Research |
| Q5_K_XL | 732GB | ❌ No (23GB) | 256GB | Perfect | Slowest | Max quality |

## How to Choose

### Decision Tree

```
Do you have Tesla T4 (16GB VRAM)?
├─ Yes → Need maximum efficiency?
│  ├─ Yes → Use UD-TQ1_0 (245GB)
│  └─ No → Have 96GB+ RAM?
│     ├─ Yes → Use UD-Q2_K_XL (381GB) ⭐
│     └─ No → Use UD-TQ1_0 (245GB)
│
└─ No (A10/V100/better) → Need maximum quality?
   ├─ Yes → Use UD-Q4_K_XL or UD-Q5_K_XL
   └─ No → Use UD-Q2_K_XL (381GB) ⭐
```

### By Use Case

| Use Case | Recommended Quant |
|----------|-------------------|
| **Development/Testing** | UD-TQ1_0 |
| **Production (T4)** | UD-Q2_K_XL |
| **Production (A10+)** | UD-Q4_K_XL |
| **Edge Deployment** | UD-IQ1_S |
| **Research** | UD-Q5_K_XL |
| **Cost-optimized** | UD-TQ1_0 |
| **Quality-optimized** | UD-Q4_K_XL |

## Changing Quantization

### Before Deployment

Edit `manifests/03-configmap.yaml`:

```yaml
data:
  QUANT_TYPE: "UD-Q2_K_XL"  # Change this line
```

Then deploy normally.

### After Deployment

```bash
# 1. Update ConfigMap
oc edit configmap kimi-k2-llamacpp-config -n llm-models-llamacpp
# Change QUANT_TYPE value

# 2. Delete the pod to trigger re-download
oc delete pod -n llm-models-llamacpp -l app=kimi-k2-llamacpp

# 3. Monitor new download
oc logs -f -n llm-models-llamacpp -l app=kimi-k2-llamacpp -c model-downloader
```

**Note:** Changing quantization will re-download the model (30-90 min).

## Storage Planning

### Disk Space Requirements

| Scenario | PVC Size | Reason |
|----------|----------|--------|
| **Single quant** | Model size + 50GB | Safe buffer |
| **UD-TQ1_0 only** | 300 GB | 245GB + buffer |
| **UD-Q2_K_XL only** | 450 GB | 381GB + buffer |
| **Both TQ1_0 + Q2_K_XL** | 650 GB | Keep multiple quants |
| **All quants** | 2 TB | Dev/experimentation |

Recommended PVC in `02-pvc.yaml`:
```yaml
storage: 400Gi  # Good for UD-Q2_K_XL + buffer
```

### Network Requirements

Download times (with 1 Gbps connection):

| Quant | Size | Time (1 Gbps) | Time (100 Mbps) |
|-------|------|---------------|-----------------|
| TQ1_0 | 245GB | ~35 min | ~5.5 hours |
| Q2_K_XL | 381GB | ~55 min | ~8.5 hours |
| Q4_K_XL | 588GB | ~85 min | ~13 hours |

**Tip:** For slow connections, download locally then copy to PVC.

## Quality Benchmarks

Based on Unsloth's testing:

### Aider Polyglot (Coding)

| Quant | Score | vs Full Precision |
|-------|-------|-------------------|
| Q5_K_XL | 99.2% | -0.8% |
| Q4_K_XL | 98.8% | -1.2% |
| Q2_K_XL | 97.5% | -2.5% |
| IQ1_S | 95.8% | -4.2% |
| TQ1_0 | 95.1% | -4.9% |

### 5-shot MMLU (Knowledge)

| Quant | Score | vs Full Precision |
|-------|-------|-------------------|
| Q5_K_XL | 99.5% | -0.5% |
| Q4_K_XL | 99.1% | -0.9% |
| Q2_K_XL | 98.3% | -1.7% |
| IQ1_S | 97.2% | -2.8% |
| TQ1_0 | 96.8% | -3.2% |

**Conclusion:** Even UD-TQ1_0 at 1.8-bit retains 95%+ performance!

## MoE Architecture Note

Kimi K2 uses **Mixture of Experts (MoE)** architecture:
- Different layers have different importance
- Expert layers can be offloaded to CPU
- Non-expert layers stay on GPU for speed

**This is why:**
- GGUF quants show "MoE/non-MoE" bit levels (e.g., 3.5/2.5)
- Tesla T4 (16GB) can run 381GB model via offloading
- RAM matters as much as VRAM

The quantization reduces ALL layers, while MoE offloading selects WHERE to run them.

## Additional Resources

- **Unsloth Documentation:** https://docs.unsloth.ai/tutorials/how-to-run/kimi-k2
- **llama.cpp Quantization:** https://github.com/ggml-org/llama.cpp/blob/master/examples/quantize/README.md
- **GGUF Format Spec:** https://github.com/ggml-org/gguf/blob/master/docs/spec.md

---

**Recommended:** Start with **UD-Q2_K_XL** for production, fall back to **UD-TQ1_0** if resource-constrained.
