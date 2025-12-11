# KAI Scheduler

**Upstream Repository:** https://github.com/NVIDIA/KAI-Scheduler

## Overview

NVIDIA KAI Scheduler is a Kubernetes scheduler designed for efficient GPU workload scheduling, enabling GPU sharing and fractional GPU allocation.

## Structure

```
kai-scheduler/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
└── upstream/                    # Upstream manifests (if any)
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/
```

## Features

- **GPU Sharing**: Share GPUs across multiple pods
- **Fractional GPUs**: Allocate fractional GPU resources
- **Queue-based Scheduling**: Priority-based workload scheduling
