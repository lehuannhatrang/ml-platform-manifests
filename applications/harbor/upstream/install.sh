#!/bin/bash

# Add Harbor Helm repository
helm repo add harbor https://helm.goharbor.io
helm repo update

# Install Harbor
helm install harbor harbor/harbor \
    --namespace harbor \
    --create-namespace \
    --set expose.type=nodePort \
    --set expose.tls.enabled=false \
    --set persistence.enabled=true \
    --set persistence.persistentVolumeClaim.registry.size=50Gi \
    --set persistence.persistentVolumeClaim.database.size=10Gi \
    --set persistence.persistentVolumeClaim.redis.size=5Gi \
    --set trivy.enabled=true

