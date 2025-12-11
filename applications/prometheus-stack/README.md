# Prometheus Stack (kube-prometheus-stack)

**Upstream Repository:** https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

## Overview

The kube-prometheus-stack provides a complete monitoring solution including Prometheus, Grafana, and Alertmanager. It's used for monitoring the ML Platform infrastructure, GPU metrics, and application performance.

## Structure

```
prometheus-stack/
├── base/
│   ├── kustomization.yaml
│   └── namespace.yaml
├── overlays/                    # Environment-specific overlays
│   ├── dashboards/              # Custom Grafana dashboards
│   ├── alerting/                # Custom alerting rules
│   └── servicemonitors/         # Custom ServiceMonitors
└── upstream/                    # Upstream manifests
    └── install.sh
```

## Installation

The prometheus-stack is installed via Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace
```

## Usage

```bash
# Apply base configuration
kubectl apply -k base/

# Apply custom dashboards
kubectl apply -k overlays/dashboards/

# Apply alerting rules
kubectl apply -k overlays/alerting/
```

## Components

### Prometheus
Time-series database and monitoring system for collecting and storing metrics.

### Grafana
Visualization and dashboarding platform for metrics and logs.

### Alertmanager
Handles alerts sent by Prometheus, including deduplication, grouping, and routing.

### Node Exporter
Exports hardware and OS metrics from nodes.

### kube-state-metrics
Generates metrics about Kubernetes objects.

## GPU Monitoring

For GPU monitoring, ensure the NVIDIA DCGM Exporter is deployed and add a ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: dcgm-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  endpoints:
    - port: metrics
      interval: 15s
  namespaceSelector:
    matchNames:
      - gpu-operator
```

## Default Dashboards

The stack includes pre-configured dashboards for:
- Kubernetes cluster overview
- Node metrics
- Pod metrics
- API server metrics
- GPU metrics (with DCGM integration)

