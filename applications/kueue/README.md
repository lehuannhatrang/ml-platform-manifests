# Kueue

**Upstream Repository:** https://github.com/kubernetes-sigs/kueue

## Overview

Kueue is a Kubernetes-native job queueing system that manages quotas and how jobs consume them. It's designed for batch workloads and ML training jobs.

## Structure

```
kueue/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/                    # Environment-specific overlays
│   └── cluster-queues/          # ClusterQueue and LocalQueue definitions
└── upstream/                    # Upstream manifests
    └── install.sh
```

## Installation

Kueue can be installed via kubectl or Helm:

```bash
# Using kubectl
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.0/manifests.yaml

# Or using Helm
helm install kueue oci://us-central1-docker.pkg.dev/k8s-staging-images/charts/kueue \
    --version="v0.10.0" \
    --namespace kueue-system \
    --create-namespace
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/

# Apply cluster queues
kubectl apply -k overlays/cluster-queues/
```

## Features

- **Job Queueing**: Queue jobs and schedule them based on available resources
- **Resource Quotas**: Define quotas for different workload types
- **Fair Sharing**: Share resources fairly across multiple tenants
- **Preemption**: Preempt lower-priority jobs when needed
- **Integration**: Works with Kubeflow Training Operator, Spark, Ray, and more

