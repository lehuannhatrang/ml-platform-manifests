# Harbor

**Upstream Repository:** https://github.com/goharbor/harbor

## Overview

Harbor is an open source container image registry that secures images with role-based access control, scans images for vulnerabilities, and signs images as trusted.

## Structure

```
harbor/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/                    # Environment-specific overlays
└── upstream/                    # Upstream manifests
    └── install.sh
```

## Installation

Harbor is typically installed via Helm:

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update

helm install harbor harbor/harbor \
    --namespace harbor \
    --create-namespace \
    --set expose.type=nodePort
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/
```

## Features

- **Container Registry**: Store and distribute container images
- **Vulnerability Scanning**: Scan images for security vulnerabilities
- **Image Signing**: Sign and verify image integrity
- **RBAC**: Role-based access control for projects and repositories
- **Replication**: Replicate images across multiple registries
- **Garbage Collection**: Clean up unused images

