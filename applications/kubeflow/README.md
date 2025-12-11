# Kubeflow

**Upstream Repository:** https://github.com/kubeflow/manifests

## Overview

Kubeflow is a machine learning platform for Kubernetes that provides components for developing, orchestrating, deploying, and running scalable ML workloads.

## Structure

```
kubeflow/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/
│   ├── centraldashboard/           # Central Dashboard UI
│   │   ├── kustomization.yaml
│   │   └── deployment.yaml
│   ├── dex/                        # Dex Identity Provider
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   └── configmap.yaml
│   ├── istio/                      # Istio Service Mesh configs
│   │   ├── kustomization.yaml
│   │   ├── authorization-policy.yaml
│   │   └── virtual-service-training-job.yaml
│   ├── jupyter-notebook/           # Jupyter Notebook components
│   │   ├── kustomization.yaml
│   │   └── enterprise-gateway/
│   │       ├── kustomization.yaml
│   │       ├── namespace.yaml
│   │       ├── configmap/
│   │       ├── deployment/
│   │       └── kyverno/
│   └── oauth2-proxy/               # OAuth2 Proxy for authentication
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       └── configmap.yaml
└── upstream/                       # Upstream manifests (if any)
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/

# Apply individual overlays
kubectl apply -k overlays/centraldashboard/
kubectl apply -k overlays/dex/
kubectl apply -k overlays/istio/
kubectl apply -k overlays/jupyter-notebook/enterprise-gateway/
kubectl apply -k overlays/oauth2-proxy/
```

## Components

### Central Dashboard
The main Kubeflow UI dashboard that provides access to all ML platform features.

### Dex
OpenID Connect identity provider that integrates with external authentication systems like Keycloak.

### Istio
Service mesh configurations including:
- **Authorization Policies**: Control access to ML Platform backend and frontend services
- **Virtual Services**: Route training job traffic through the Kubeflow gateway

### Jupyter Enterprise Gateway
Enables remote kernel execution for Jupyter notebooks with GPU sharing support:
- **GPU Fractional Kernel**: Allows multiple notebooks to share a single GPU
- **Kyverno Policy**: Automatically injects gateway environment variables into notebook pods
- **KAI Scheduler Integration**: Uses KAI Scheduler for GPU-aware scheduling

### OAuth2 Proxy
Handles authentication flow for Kubeflow services, integrating with Dex for OIDC-based authentication.
