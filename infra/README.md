# Infrastructure

This directory contains infrastructure configuration for the ML Platform.

## Structure

```
infra/
├── README.md
└── kubeadm/                    # Kubernetes cluster setup
    ├── README.md
    ├── kubeadm-config.yaml     # Control plane configuration
    ├── kubeadm-join-config.yaml # Worker node configuration
    ├── install-prerequisites.sh # Prerequisites installation
    └── init-cluster.sh         # Cluster initialization
```

## Kubernetes Cluster Setup

### Requirements

- Ubuntu 22.04+ or similar Linux distribution
- 2+ CPU cores per node
- 4GB+ RAM per node
- Unique hostname, MAC address, and product_uuid for each node
- Network connectivity between nodes

### Quick Start

```bash
# On all nodes
cd kubeadm
sudo ./install-prerequisites.sh

# On control plane node
sudo ./init-cluster.sh

# On worker nodes (use join command from init output)
sudo kubeadm join <control-plane>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

## Features Enabled

| Feature | Description |
|---------|-------------|
| **DRA** | Dynamic Resource Allocation for fine-grained GPU scheduling |
| **resource.k8s.io/v1beta1** | DRA API for ResourceSlices, ResourceClaims |
| **CRI-O** | Container runtime with systemd cgroup driver |
| **IPVS** | kube-proxy in IPVS mode for better performance |

## Version

- Kubernetes: **1.34.2**
- kubeadm API: v1beta4

