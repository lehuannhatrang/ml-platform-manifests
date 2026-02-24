terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "coder" {}

# Use default K8s configuration (In-cluster when running on Coder Server, Kubeconfig when Admin pushes template)
provider "kubernetes" {
  config_path = null
}

# -------------------------------------------------------------------------
# 1. SCAN NODES AND CONFIGURE PARAMETERS
# -------------------------------------------------------------------------

# Get current logged-in user information
data "coder_workspace" "me" {}

# Scan all K8s Nodes to get the actual list of GPU cards
data "kubernetes_nodes" "all" {}

locals {
  # Calculate Kubeflow Namespace from Email (e.g., huanle@gmail.com -> huanle-gmail-com)
  user_email         = data.coder_workspace.me.owner_email
  kubeflow_namespace = local.user_email == "" ? "dry-run-user" : replace(replace(local.user_email, "@", "-"), ".", "-")

  # Filter the list of existing "gpu-type" labels on the Cluster (remove duplicates)
  gpu_types = distinct(compact([
    for node in data.kubernetes_nodes.all.nodes : 
    lookup(node.metadata[0].labels, "gpu-type", "")
  ]))

  # Default Image configuration
  container_image = "docker.io/pytorch/pytorch:2.4.1-cuda12.1-cudnn9-runtime"
}

# Create Parameter (Dropdown menu) for User to select GPU type
data "coder_parameter" "kernel_gpu_type" {
  name         = "kernel_gpu_type"
  display_name = "GPU Type (Node Selector)"
  description  = "Select the GPU card to use. This list is automatically scanned from the Cluster."
  default      = length(local.gpu_types) > 0 ? local.gpu_types[0] : ""
  icon         = "/icon/memory.svg"
  
  # Automatically generate Options based on current hardware configuration
  dynamic "option" {
    for_each = local.gpu_types
    content {
      name  = "GPU Type: ${option.value}"
      value = option.value
    }
  }
}

data "coder_parameter" "gpu_memory" {
  name         = "gpu_memory"
  display_name = "Request VRAM (MiB)"
  description  = "Enter the amount of VRAM (GPU Memory) to allocate for the Pod."
  default      = "4000"
  type         = "number"
  icon         = "/icon/database.svg"

  # mutable = true allows users to change the VRAM amount each time they Stop and Start the Workspace
  mutable      = true
}

# -------------------------------------------------------------------------
# 2. INITIALIZE CODER AGENT & PERSISTENT STORAGE (PVC)
# -------------------------------------------------------------------------

# Coder Agent: The heart of the Workspace, enabling VS Code SSH into the container
resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<EOT
    #!/bin/bash
    echo "Initializing VS Code Remote environment..."
  EOT
}

# PVC: Persistent storage volume (persists even when Workspace is stopped)
resource "kubernetes_persistent_volume_claim" "workspace_data" {
  metadata {
    name      = "coder-pvc-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
    namespace = local.kubeflow_namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi" # Default storage size for the Workspace
      }
    }
  }
}

# -------------------------------------------------------------------------
# 3. POD PROVISIONING (ONLY RUNS WHEN WORKSPACE STATE IS 'START')
# -------------------------------------------------------------------------

resource "kubernetes_pod" "workspace" {
  # Crucial: Only create the Pod in K8s when the user starts the workspace
  count = data.coder_workspace.me.transition == "start" ? 1 : 0

  metadata {
    name      = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
    namespace = local.kubeflow_namespace
    
    # Integrate Kai Scheduler Queue
    labels = {
      "kai.scheduler/queue" = "${local.kubeflow_namespace}-queue"
    }
    
    annotations = {
      "gpu-memory" = tostring(data.coder_parameter.gpu_memory.value)
    }
  }

  spec {
    # Configure Scheduler and CDI for GPU
    scheduler_name     = "kai-scheduler"
    runtime_class_name = "nvidia-cdi"

    # Require Node containing the GPU type selected by the User in the Parameter
    node_selector = {
      "gpu-type" = data.coder_parameter.kernel_gpu_type.value
    }

    container {
      name    = "dev"
      image   = local.container_image
      
      # Startup command (Note: Your Image MUST have curl or wget installed for the Agent to download the binary file)
      command = ["sh", "-c", "apt-get update && apt-get install -y curl wget && ${coder_agent.main.init_script}"]
      
      security_context {
        run_as_user = "0" # Run as root by default (can be adjusted depending on Lab policy)
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      # Mount PVC into the /home/coder/workspace directory inside the Pod
      volume_mount {
        name       = "workspace-data"
        mount_path = "/home/coder/workspace"
      }
    }

    # Define Volume referencing the PVC created in the block above
    volume {
      name = "workspace-data"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.workspace_data.metadata[0].name
      }
    }
  }
}