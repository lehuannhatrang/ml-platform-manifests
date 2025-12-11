# ML Platform Manifests

This repository contains Kubernetes manifests for the ML Platform. It follows a Kustomize structure with base configurations and overlays for different environments.

## Applications

| Application | Description | Upstream Repository |
|-------------|-------------|---------------------|
| **gpu-operator** | NVIDIA GPU Operator for Kubernetes | [NVIDIA/gpu-operator](https://github.com/NVIDIA/gpu-operator) |
| **k8s-dra-driver-gpu** | Kubernetes DRA Driver for NVIDIA GPUs | [NVIDIA/k8s-dra-driver-gpu](https://github.com/NVIDIA/k8s-dra-driver-gpu) |
| **kai-scheduler** | NVIDIA KAI Scheduler for GPU sharing | [NVIDIA/KAI-Scheduler](https://github.com/NVIDIA/KAI-Scheduler) |
| **kubeflow** | Kubeflow ML Platform components | [kubeflow/manifests](https://github.com/kubeflow/manifests) |
| **ml-platform-admin** | ML Platform Admin Dashboard | [lehuannhatrang/ml-platform-admin](https://github.com/lehuannhatrang/ml-platform-admin) |

## Structure

```
applications/
├── <app-name>/
│   ├── README.md           # Application documentation
│   ├── upstream/           # Upstream manifests (from vendor)
│   ├── base/               # Base kustomization
│   │   └── kustomization.yaml
│   └── overlays/           # Environment-specific overlays
│       └── <overlay-name>/
│           └── kustomization.yaml
```

## Usage

To apply manifests using Kustomize:

```bash
# Apply base configuration
kubectl apply -k applications/<app-name>/base

# Apply overlay
kubectl apply -k applications/<app-name>/overlays/<overlay-name>
```

## License

See [LICENSE](LICENSE) for details.
