# Kubernetes DRA Driver for NVIDIA GPUs

**Upstream Repository:** https://github.com/NVIDIA/k8s-dra-driver-gpu

## Overview

The NVIDIA DRA (Dynamic Resource Allocation) Driver enables fine-grained GPU resource allocation in Kubernetes using the DRA framework introduced in Kubernetes 1.26+.

## Structure

```
k8s-dra-driver-gpu/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
└── upstream/
    └── install.sh              # Helm installation script
```

## Installation

The DRA driver is installed via Helm. See `upstream/install.sh` for the installation command:

```bash
helm install nvidia-dra-driver-gpu nvidia/nvidia-dra-driver-gpu \
    --version="25.8.0" \
    --create-namespace \
    --namespace nvidia-dra-driver-gpu \
    --set resources.gpus.enabled=true \
    --set gpuResourcesEnabledOverride=true \
    --set featureGates.TimeSlicingSettings=true \
    --set featureGates.MPSSupport=true
```

## Features

- **GPU Resources**: Native GPU resource allocation
- **Time Slicing**: GPU time-slicing support
- **MPS Support**: Multi-Process Service for GPU sharing
