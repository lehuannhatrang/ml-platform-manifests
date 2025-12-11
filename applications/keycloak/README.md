# Keycloak

**Upstream Repository:** https://github.com/keycloak/keycloak

## Overview

Keycloak is an open source Identity and Access Management solution. It provides user federation, identity brokering, and social login capabilities for the ML Platform.

## Structure

```
keycloak/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/                    # Environment-specific overlays
│   └── realm-config/            # Realm and client configurations
└── upstream/                    # Upstream manifests
    └── install.sh
```

## Installation

Keycloak can be installed via Helm:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install keycloak bitnami/keycloak \
    --namespace keycloak \
    --create-namespace
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/

# Apply realm configuration
kubectl apply -k overlays/realm-config/
```

## Integration with ML Platform

Keycloak is the central identity provider for the ML Platform:

1. **Dex Integration**: Dex connects to Keycloak as an OIDC provider
2. **Kubeflow Authentication**: Users authenticate via Keycloak → Dex → OAuth2 Proxy
3. **RBAC**: Keycloak groups map to Kubernetes RBAC roles

## Default Realm Configuration

The ML Platform uses the `ml-platform` realm with:

- **Client**: `kubeflow-oidc-authservice`
- **Scopes**: `openid`, `profile`, `email`, `offline_access`
- **Groups**: Map to Kubeflow profiles and namespaces

## Features

- **Single Sign-On (SSO)**: One login for all platform services
- **Identity Federation**: Connect to external identity providers
- **User Management**: Self-service user registration and management
- **Fine-grained Authorization**: Role-based and attribute-based access control
- **Multi-tenancy**: Support for multiple realms and organizations

