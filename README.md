# ML Platform Manifests

This repository contains Kubernetes manifests for the ML Platform. It follows a Kustomize structure with base configurations and overlays for different environments.

## Applications

### GPU & Scheduling

| Application | Description | Upstream Repository |
|-------------|-------------|---------------------|
| **gpu-operator** | NVIDIA GPU Operator for Kubernetes | [NVIDIA/gpu-operator](https://github.com/NVIDIA/gpu-operator) |
| **k8s-dra-driver-gpu** | Kubernetes DRA Driver for NVIDIA GPUs | [NVIDIA/k8s-dra-driver-gpu](https://github.com/NVIDIA/k8s-dra-driver-gpu) |
| **kai-scheduler** | NVIDIA KAI Scheduler for GPU sharing | [NVIDIA/KAI-Scheduler](https://github.com/NVIDIA/KAI-Scheduler) |
| **kueue** | Kubernetes-native job queueing | [kubernetes-sigs/kueue](https://github.com/kubernetes-sigs/kueue) |

### ML Platform

| Application | Description | Upstream Repository |
|-------------|-------------|---------------------|
| **kubeflow** | Kubeflow ML Platform components | [kubeflow/manifests](https://github.com/kubeflow/manifests) |
| **ml-platform-admin** | ML Platform Admin Dashboard | [lehuannhatrang/ml-platform-admin](https://github.com/lehuannhatrang/ml-platform-admin) |

### Identity & Access Management

| Application | Description | Upstream Repository |
|-------------|-------------|---------------------|
| **keycloak** | Identity and Access Management | [keycloak/keycloak](https://github.com/keycloak/keycloak) |
| **kyverno** | Kubernetes Policy Engine | [kyverno/kyverno](https://github.com/kyverno/kyverno) |

### Storage & Registry

| Application | Description | Upstream Repository |
|-------------|-------------|---------------------|
| **harbor** | Container Image Registry | [goharbor/harbor](https://github.com/goharbor/harbor) |
| **minio** | S3-compatible Object Storage | [minio/minio](https://github.com/minio/minio) |

### Monitoring

| Application | Description | Upstream Repository |
|-------------|-------------|---------------------|
| **prometheus-stack** | Prometheus, Grafana & Alertmanager | [prometheus-community/helm-charts](https://github.com/prometheus-community/helm-charts) |

## Structure

```
applications/
├── <app-name>/
│   ├── README.md           # Application documentation
│   ├── upstream/           # Upstream manifests (from vendor)
│   │   └── install.sh      # Helm/kubectl installation script
│   ├── base/               # Base kustomization
│   │   ├── kustomization.yaml
│   │   └── namespace.yaml
│   └── overlays/           # Environment-specific overlays
│       └── <overlay-name>/
│           └── kustomization.yaml
```

## Usage

### Apply base configuration

```bash
kubectl apply -k applications/<app-name>/base
```

### Apply overlay

```bash
kubectl apply -k applications/<app-name>/overlays/<overlay-name>
```

### Install via Helm (upstream)

Most applications can be installed using the provided Helm scripts:

```bash
cd applications/<app-name>/upstream
./install.sh
```

## Quick Start

Install the core ML Platform components:

```bash
# 1. Identity & Access
./applications/keycloak/upstream/install.sh
./applications/kyverno/upstream/install.sh

# 2. GPU Support
./applications/gpu-operator/upstream/install.sh
./applications/k8s-dra-driver-gpu/upstream/install.sh
./applications/kai-scheduler/upstream/install.sh

# 3. Storage
./applications/minio/upstream/install.sh
./applications/harbor/upstream/install.sh

# 4. Monitoring
./applications/prometheus-stack/upstream/install.sh

# 5. Job Queueing
./applications/kueue/upstream/install.sh

# 6. Apply Kubeflow overlays
kubectl apply -k applications/kubeflow/overlays/dex/
kubectl apply -k applications/kubeflow/overlays/oauth2-proxy/
kubectl apply -k applications/kubeflow/overlays/centraldashboard/
kubectl apply -k applications/kubeflow/overlays/istio/
kubectl apply -k applications/kubeflow/overlays/jupyter-notebook/enterprise-gateway/
```

## License

See [LICENSE](LICENSE) for details.
