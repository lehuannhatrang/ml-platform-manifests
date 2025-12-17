# Jupyter Enterprise Gateway

**Upstream Repository:** https://github.com/jupyter-server/enterprise_gateway

## Overview

Jupyter Enterprise Gateway is a lightweight, multi-tenant, scalable, and secure gateway that enables Jupyter Notebooks to share resources across distributed clusters. It provides remote kernel management for Jupyter environments, enabling:

- **GPU Sharing**: Multiple notebooks can share GPU resources via KAI Scheduler integration
- **Remote Kernels**: Kernels run as separate pods in Kubernetes
- **Resource Management**: Fine-grained control over kernel resource allocation

## Structure

```
enterprise-gateway/
├── base/
│   ├── values.yaml              # Helm values for reference
│   ├── serviceaccount.yaml      # ServiceAccount for gateway
│   ├── clusterrole.yaml         # RBAC roles for gateway and kernels
│   ├── clusterrolebinding.yaml  # Role bindings
│   └── service.yaml             # Gateway service
├── overlays/
│   ├── configmap/
│   │   ├── tf-gpu-sharing.yaml      # TensorFlow GPU sharing kernel
│   │   └── pytorch-gpu-sharing.yaml # PyTorch GPU sharing kernel
│   ├── deployment/
│   │   └── enterprise-gateway.yaml  # Gateway deployment
│   └── kyverno/
│       └── inject-jeg-env.yaml      # Policy to inject gateway URL
├── namespace.yaml
└── kustomization.yaml
```

## Installation

### Using Kustomize

```bash
# Apply the complete enterprise-gateway stack
kubectl apply -k .
```

### Using Helm

```bash
helm repo add jupyter https://jupyter-server.github.io/enterprise_gateway/
helm repo update

helm install enterprise-gateway jupyter/enterprise-gateway \
    --namespace enterprise-gateway \
    --create-namespace \
    -f base/values.yaml
```

## Components

### Gateway Deployment
The main Enterprise Gateway service that manages kernel lifecycle.

### GPU Sharing Kernels
Custom kernel specifications for GPU sharing:

- **TensorFlow GPU Sharing** (`tf_gpu_sharing`): TensorFlow kernel with fractional GPU support
- **PyTorch GPU Sharing** (`pytorch_gpu_sharing`): PyTorch kernel with fractional GPU support

Both kernels use:
- **KAI Scheduler**: For GPU-aware scheduling
- **nvidia-cdi RuntimeClass**: For NVIDIA CDI-based GPU access
- **Fractional GPU annotation**: `gpu-fraction: "0.15"` for GPU sharing

### Kyverno Policy
Automatically injects Enterprise Gateway environment variables into Kubeflow Notebook pods:
- `JUPYTER_GATEWAY_URL`: Gateway endpoint for kernel connections
- `JUPYTER_GATEWAY_REQUEST_TIMEOUT`: Timeout for gateway requests
- `KERNEL_GPUS`: Default GPU request for kernels

## Integration with Kubeflow

Enterprise Gateway integrates with Kubeflow Notebooks to provide remote kernel execution:

1. Notebooks connect to Enterprise Gateway instead of local kernels
2. Gateway spawns kernel pods in the `enterprise-gateway` namespace
3. Kyverno policy automatically configures notebooks to use the gateway

## Configuration

### Environment Variables (Gateway)

| Variable | Description | Default |
|----------|-------------|---------|
| `EG_PORT` | Gateway HTTP port | 8888 |
| `EG_RESPONSE_PORT` | Kernel response port | 8877 |
| `EG_CULL_IDLE_TIMEOUT` | Idle kernel timeout (seconds) | 300 |
| `EG_KERNEL_LAUNCH_TIMEOUT` | Kernel startup timeout | 300 |
| `EG_LOG_LEVEL` | Logging level | DEBUG |
| `EG_SHARED_NAMESPACE` | Share namespace across kernels | True |

### Kernel Environment Variables

| Variable | Description |
|----------|-------------|
| `KERNEL_GPUS` | GPU request for kernel |
| `KERNEL_GPUS_LIMIT` | GPU limit for kernel |
| `KERNEL_CPUS` | CPU request for kernel |
| `KERNEL_MEMORY` | Memory request for kernel |







