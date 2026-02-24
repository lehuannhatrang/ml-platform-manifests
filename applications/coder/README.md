# Coder

**Upstream Repository:** https://github.com/coder/coder
**Docs:** https://coder.com/docs/install/kubernetes

## Overview

Coder is an open-source cloud development environment (CDE) platform that enables developers to create consistent, secure, and reproducible workspaces running on Kubernetes.

## Structure

```
coder/
├── base/
│   ├── kustomization.yaml              # Kustomize base configuration
│   ├── namespace.yaml                  # Namespace definition
│   ├── values.yaml                     # Coder Helm chart values
│   ├── postgresql-values.yaml          # PostgreSQL Helm chart values
│   └── secret-db-url.yaml              # Database connection secret
├── overlay/
│   ├── rbac/
│   │   ├── kustomization.yaml          # RBAC overlay
│   │   └── coder-rbac.yaml             # ClusterRole + ClusterRoleBinding
│   └── templates/
│       └── k8s-gpu-workspace/
│           ├── main.tf                  # Terraform template for GPU workspaces
│           └── README.md
└── README.md
```

## Installation

Coder requires a PostgreSQL database. Both are installed via Helm charts.

### 1. Apply Kustomize base (namespace + secret)

```bash
kubectl apply -k base/
```

### 2. Install PostgreSQL

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install postgresql bitnami/postgresql \
    --namespace coder \
    -f base/postgresql-values.yaml
```

### 3. Install Coder

```bash
helm repo add coder-v2 https://helm.coder.com/v2
helm repo update

helm install coder coder-v2/coder \
    --namespace coder \
    --values base/values.yaml \
    --version 2.30.0
```

### 4. Apply RBAC overlay (workspace provisioner permissions)

```bash
kubectl apply -k overlay/rbac/
```

### 5. Push Coder templates

```bash
coder templates push k8s-gpu-workspace \
    --directory overlay/templates/k8s-gpu-workspace
```

## Configuration

| Parameter | Description | Location |
|-----------|-------------|----------|
| PostgreSQL credentials | DB username, password, database name | `base/postgresql-values.yaml` |
| DB connection URL | Postgres connection string for Coder | `base/secret-db-url.yaml` |
| OIDC / OAuth2 | SSO configuration via Dex | `base/values.yaml` |
| Service type | NodePort (port 32272) | `base/values.yaml` |
| Access URL | External access URL for Coder | `base/values.yaml` |

## Features

- **Cloud Development Environments**: Consistent, reproducible dev workspaces
- **Kubernetes-native**: Workspaces run as Kubernetes pods
- **Terraform Templates**: Infrastructure-as-code workspace definitions
- **OIDC Integration**: Single sign-on via Dex/Keycloak
- **RBAC**: Role-based access control for users and workspaces
- **GPU Workspaces**: Dynamic GPU discovery with Kai Scheduler + NVIDIA CDI integration
- **Persistent Storage**: PVC-backed workspace data survives stop/start cycles
- **OIDC Integration**: Single sign-on via Dex/Keycloak
- **RBAC**: Role-based access control for users and workspaces
