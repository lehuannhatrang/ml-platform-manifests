# MinIO

**Upstream Repository:** https://github.com/minio/minio

## Overview

MinIO is a high-performance, S3-compatible object storage system. It's used for storing ML artifacts, datasets, model checkpoints, and pipeline outputs.

## Structure

```
minio/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/                    # Environment-specific overlays
└── upstream/                    # Upstream manifests
    └── install.sh
```

## Installation

MinIO can be installed via Helm:

```bash
helm repo add minio https://charts.min.io/
helm repo update

helm install minio minio/minio \
    --namespace minio \
    --create-namespace \
    --set mode=standalone \
    --set persistence.size=100Gi
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/
```

## Features

- **S3 Compatible**: Full S3 API compatibility
- **High Performance**: Designed for high-throughput workloads
- **Erasure Coding**: Data protection with erasure coding
- **Bucket Policies**: Fine-grained access control
- **Versioning**: Object versioning support
- **Lifecycle Management**: Automatic data lifecycle policies

## Integration with Kubeflow

MinIO is commonly used as the artifact store for:
- Kubeflow Pipelines artifacts
- Model registry storage
- Training data and datasets
- Experiment tracking artifacts

