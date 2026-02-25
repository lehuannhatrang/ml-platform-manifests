terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.10"
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
data "coder_workspace_owner" "me" {}

# Scan all K8s Nodes to get the actual list of GPU cards
data "kubernetes_nodes" "all" {}

locals {
  # Calculate Kubeflow Namespace from Email (e.g., huanle@gmail.com -> huanle-gmail-com)
  user_email         = data.coder_workspace_owner.me.email
  kubeflow_namespace = local.user_email == "" ? "dry-run-user" : replace(replace(local.user_email, "@", "-"), ".", "-")

  # Filter the list of existing "gpu-type" labels on the Cluster (remove duplicates)
  gpu_types = distinct(compact([
    for node in data.kubernetes_nodes.all.nodes : 
    lookup(node.metadata[0].labels, "gpu-type", "")
  ]))

  # Default Image configuration
  # container_image = "docker.io/pytorch/pytorch:2.4.1-cuda12.1-cudnn9-runtime"
  container_image = "192.168.40.246:30080/khamb/jupyter_kernel_torch_cuda:latest"

  # Whether GPU is enabled ("none" means CPU-only)
  use_gpu = data.coder_parameter.kernel_gpu_type.value != "none"
}

# Create Parameter (Dropdown menu) for User to select GPU type or None for CPU-only
data "coder_parameter" "kernel_gpu_type" {
  name         = "kernel_gpu_type"
  display_name = "GPU Type"
  description  = "Select the GPU card to use, or 'None' for a CPU-only workspace. GPU list is automatically scanned from the Cluster."
  type         = "string"
  default      = "none"
  icon         = "/icon/memory.svg"
  form_type    = "dropdown"
  
  option {
    name  = "None (CPU Only)"
    value = "none"
  }

  # Automatically generate Options based on current hardware configuration
  dynamic "option" {
    for_each = local.gpu_types
    content {
      name  = "GPU Type: ${option.value}"
      value = option.value
    }
  }
  mutable     = true
  order        = 3
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
  order        = 4
  styling      = jsonencode({
    disabled = data.coder_parameter.kernel_gpu_type.value == "none"
  })
}

# Parameter for CPU request
data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores to allocate for the Pod."
  default      = "2"
  type         = "number"
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 1

  validation {
    min = 1
    max = 64
  }
}

# Parameter for Memory request
data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GiB)"
  description  = "Amount of RAM to allocate for the Pod."
  default      = "4"
  type         = "number"
  icon         = "/icon/database.svg"
  mutable      = true
  order        = 2

  validation {
    min = 1
    max = 256
  }
}

data "coder_parameter" "workspace_storage" {
  name         = "workspace_storage"
  display_name = "Workspace Storage (GiB)"
  description  = "Enter the amount of storage to allocate (e.g., 20, 50, 100)."
  default      = "10"
  type         = "string"
  icon         = "/icon/database.svg"
  mutable      = true 
  order        = 5
  
  validation {
    regex = "^([1-9][0-9]|[1-4][0-9]{2}|500)$"
    error = "Storage size must be between 10 and 500 GiB."
  }
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
    name      = "coder-pvc-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = local.kubeflow_namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.workspace_storage.value}Gi"
      }
    }
  }
}

# -------------------------------------------------------------------------
# 3. POD PROVISIONING (ONLY RUNS WHEN WORKSPACE STATE IS 'START')
# -------------------------------------------------------------------------

resource "kubernetes_pod" "workspace" {
  # Crucial: Only create the Pod in K8s when the user starts the workspace
  count = data.coder_workspace.me.start_count > 0 ? 1 : 0

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = local.kubeflow_namespace
    
    # Integrate Kai Scheduler Queue (only when GPU is enabled)
    labels = local.use_gpu ? {
      "kai.scheduler/queue" = "${local.kubeflow_namespace}-queue"
    } : {}
    
    annotations = local.use_gpu ? {
      "gpu-memory" = tostring(data.coder_parameter.gpu_memory.value)
    } : {}
  }

  spec {
    # Configure Scheduler and CDI for GPU (only when GPU is enabled)
    scheduler_name     = local.use_gpu ? "kai-scheduler" : null
    runtime_class_name = local.use_gpu ? "nvidia-cdi" : null

    # Require Node containing the GPU type selected by the User in the Parameter (only when GPU is enabled)
    node_selector = local.use_gpu ? {
      "gpu-type" = data.coder_parameter.kernel_gpu_type.value
    } : {}

    container {
      name    = "dev"
      image   = local.container_image
      
      # Startup command (Note: Your Image MUST have curl or wget installed for the Agent to download the binary file)
      # command = ["sh", "-c", "apt-get update && apt-get install -y curl wget && ${coder_agent.main.init_script}"]
      command = ["sh", "-c", coder_agent.main.init_script]
      
      security_context {
        run_as_user = "0" # Run as root by default (can be adjusted depending on Lab policy)
      }

      # CPU and Memory resource requests
      resources {
        requests = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
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