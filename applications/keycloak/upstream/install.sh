#!/bin/bash

# Add Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Keycloak
helm install keycloak bitnami/keycloak \
    --namespace keycloak \
    --create-namespace \
    --set auth.adminUser=admin \
    --set auth.adminPassword=admin \
    --set service.type=NodePort \
    --set service.nodePorts.http=32008 \
    --set postgresql.enabled=true \
    --set postgresql.auth.postgresPassword=keycloak \
    --set postgresql.auth.database=keycloak \
    --set production=false

# For production with external database:
# helm install keycloak bitnami/keycloak \
#     --namespace keycloak \
#     --create-namespace \
#     --set auth.adminUser=admin \
#     --set auth.adminPassword=<secure-password> \
#     --set externalDatabase.host=<db-host> \
#     --set externalDatabase.port=5432 \
#     --set externalDatabase.user=keycloak \
#     --set externalDatabase.password=<db-password> \
#     --set externalDatabase.database=keycloak \
#     --set postgresql.enabled=false \
#     --set production=true

