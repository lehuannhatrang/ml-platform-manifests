# GPU Operator

**Upstream Repository:** https://github.com/NVIDIA/gpu-operator

## Overview

NVIDIA GPU Operator creates/configures/manages GPUs on Kubernetes. It automates the management of all NVIDIA software components needed to provision and monitor GPUs.

## Structure

```
gpu-operator/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/
│   └── dcgm-exporter/          # DCGM Exporter with DRA support
│       ├── kustomization.yaml
│       ├── clusterrole/
│       │   └── dra-clusterrole.yaml
│       └── daemonset/
│           └── nvidia-dcgm-exporter.yaml
└── upstream/                    # Upstream manifests (if any)
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/

# Apply DCGM exporter overlay with DRA support
kubectl apply -k overlays/dcgm-exporter/
```

## Components

- **DCGM Exporter**: Exports GPU metrics for Prometheus monitoring with DRA (Dynamic Resource Allocation) support enabled.
