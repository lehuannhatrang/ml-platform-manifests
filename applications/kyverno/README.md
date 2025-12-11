# Kyverno

**Upstream Repository:** https://github.com/kyverno/kyverno

## Overview

Kyverno is a policy engine designed for Kubernetes. It can validate, mutate, and generate Kubernetes resources based on customizable policies.

## Structure

```
kyverno/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/                    # Environment-specific overlays
│   └── policies/                # Custom policies
└── upstream/                    # Upstream manifests
    └── install.sh
```

## Installation

Kyverno is typically installed via Helm:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/

# Apply custom policies
kubectl apply -k overlays/policies/
```

## Features

- **Policy Validation**: Validate resources against policies before admission
- **Mutation**: Automatically modify resources based on policies
- **Generation**: Generate new resources based on triggers
- **Image Verification**: Verify container image signatures

