#!/bin/bash

KUEUE_VERSION="v0.10.0"

# Install Kueue using kubectl
kubectl apply --server-side -f "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"

# Alternatively, install using Helm:
# helm install kueue oci://us-central1-docker.pkg.dev/k8s-staging-images/charts/kueue \
#     --version="${KUEUE_VERSION}" \
#     --namespace kueue-system \
#     --create-namespace

