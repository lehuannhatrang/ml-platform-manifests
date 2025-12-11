# ML Platform Admin

**Upstream Repository:** https://github.com/lehuannhatrang/ml-platform-admin

## Overview

ML Platform Admin provides an administrative dashboard for managing the ML Platform, including user management, resource monitoring, and platform configuration.

## Structure

```
ml-platform-admin/
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

- **User Management**: Manage platform users and permissions
- **Resource Monitoring**: Monitor GPU and compute resource usage
- **Platform Configuration**: Configure platform settings and policies
