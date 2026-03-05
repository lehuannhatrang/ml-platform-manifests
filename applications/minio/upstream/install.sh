#!/bin/bash

# Add MinIO Helm repository
helm repo add minio https://charts.min.io/
helm repo update

# Install MinIO (standalone mode for development)
helm install minio minio/minio \
    --namespace minio \
    --create-namespace \
    --set mode=standalone \
    --set persistence.enabled=true \
    --set persistence.size=100Gi \
    --set resources.requests.memory=512Mi \
    --set rootUser=minio \
    --set rootPassword=minio123 \
    --set consoleIngress.enabled=false \
    --set service.type=ClusterIP

# For production, use distributed mode:
# helm install minio minio/minio \
#     --namespace minio \
#     --create-namespace \
#     --set mode=distributed \
#     --set replicas=4 \
#     --set persistence.enabled=true \
#     --set persistence.size=500Gi

