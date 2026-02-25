#!/bin/bash
set -e

KUBERNETES_VERSION="1.34.2"

echo "=== Installing Kubernetes ${KUBERNETES_VERSION} Prerequisites ==="

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
echo "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set required sysctl parameters
echo "Configuring sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install CRI-O
echo "Installing CRI-O..."
CRIO_VERSION="v1.34"
apt-get update
apt-get install -y ca-certificates curl gnupg

curl -fsSL https://download.opensuse.org/repositories/isv:/kubernetes:/addons:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/kubernetes:/addons:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" | \
  tee /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y cri-o

# Enable CRI-O
systemctl enable crio
systemctl start crio

# Install kubeadm, kubelet, kubectl
echo "Installing Kubernetes components v${KUBERNETES_VERSION}..."
apt-get install -y apt-transport-https

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=${KUBERNETES_VERSION}-* kubeadm=${KUBERNETES_VERSION}-* kubectl=${KUBERNETES_VERSION}-*
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

echo "=== Prerequisites installed successfully ==="
echo "Kubernetes version: ${KUBERNETES_VERSION}"
echo ""
echo "Next steps:"
echo "  Control plane: kubeadm init --config kubeadm-config.yaml"
echo "  Worker nodes:  kubeadm join --config kubeadm-join-config.yaml"

