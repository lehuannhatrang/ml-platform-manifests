# Coder Template: k8s-gpu-workspace

Terraform template for Coder that provisions GPU-enabled Kubernetes workspaces.

## Features

- **Dynamic GPU discovery**: Scans cluster nodes for available GPU types and presents them as a dropdown
- **Configurable VRAM**: Users can request specific GPU memory (MiB) per workspace
- **Kai Scheduler integration**: Pods are scheduled via `kai-scheduler` with queue labels
- **NVIDIA CDI runtime**: Uses `nvidia-cdi` RuntimeClass for GPU access
- **Persistent storage**: 20Gi PVC mounted at `/home/coder/workspace`
- **Kubeflow namespace mapping**: Workspace pods are created in the user's Kubeflow profile namespace (derived from email)

## Usage

Push this template to Coder:

```bash
cd applications/coder/overlay/templates/k8s-gpu-workspace
coder templates push k8s-gpu-workspace --directory .
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kernel_gpu_type` | GPU type (node selector label) | First available GPU type |
| `gpu_memory` | VRAM allocation in MiB | `4000` |
