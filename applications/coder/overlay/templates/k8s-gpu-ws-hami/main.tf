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
  kubeflow_namespace = data.coder_workspace_owner.me.email == "" ? "dry-run-user" : replace(replace(data.coder_workspace_owner.me.email, "@", "-"), ".", "-")

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

  # Whether to create a new PVC or reuse an existing one by name
  create_new_pvc = data.coder_parameter.create_new_pvc.value == "true"

  # The actual PVC name to use
  computed_pvc_name = data.coder_parameter.pvc_name.value
}

# Create Parameter (Dropdown menu) for User to select GPU type or None for CPU-only
data "coder_parameter" "kernel_gpu_type" {
  name         = "kernel_gpu_type"
  display_name = "GPU Type"
  description  = "Select the GPU card to use, or 'None' for a CPU-only workspace. GPU list is automatically scanned from the Cluster."
  type         = "string"
  default      = "none"
  icon         = "/icon/memory.svg"

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
  mutable = true
  order   = 3
}

data "coder_parameter" "gpu_memory" {
  name         = "gpu_memory"
  display_name = "Request VRAM (MiB)"
  description  = "Enter the amount of VRAM (GPU Memory) to allocate for the Pod."
  default      = "4000"
  type         = "number"
  icon         = "/icon/database.svg"

  # mutable = true allows users to change the VRAM amount each time they Stop and Start the Workspace
  mutable = true
  order   = 4
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
  display_name = "New PVC Storage Size (GiB)"
  description  = "Storage size for the new PVC. Ignored when 'Create New PVC' is unchecked."
  default      = "20"
  type         = "string"
  icon         = "/icon/database.svg"
  mutable      = true
  order        = 5

  validation {
    regex = "^([1-9][0-9]|[1-4][0-9]{2}|500)$"
    error = "Storage size must be between 10 and 500 GiB."
  }
}

# Whether to create a new PVC or reuse an existing one by name
data "coder_parameter" "create_new_pvc" {
  name         = "create_new_pvc"
  display_name = "Create New PVC?"
  description  = "If enabled, a new PVC will be created with the name below. Disable to reuse an existing PVC."
  type         = "bool"
  default      = "true"
  icon         = "/icon/database.svg"
  mutable      = false
  order        = 6
}

# PVC name — either a new name to create, or an existing PVC name to reuse
data "coder_parameter" "pvc_name" {
  name         = "pvc_name"
  display_name = "PVC Name"
  description  = "Name of the PVC to mount. If 'Create New PVC' is enabled, this PVC will be created. Otherwise it must already exist in your namespace."
  type         = "string"
  default      = "coder-pvc-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  icon         = "/icon/database.svg"
  mutable      = false
  order        = 7
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

# PVC: Persistent storage volume (only created when "Create New PVC" is selected)
resource "kubernetes_persistent_volume_claim" "workspace_data" {
  count = local.create_new_pvc ? 1 : 0

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
  count = data.coder_workspace.me.transition == "start" ? 1 : 0

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = local.kubeflow_namespace
  }

  spec {
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
        limits = merge(
          {
            cpu    = "${data.coder_parameter.cpu.value}"
            memory = "${data.coder_parameter.memory.value}Gi"
          },
          local.use_gpu ? {
            "nvidia.com/gpu"    = "1"
            "nvidia.com/gpumem" = tostring(data.coder_parameter.gpu_memory.value)
          } : {}
        )
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

    # Define Volume referencing the selected or newly created PVC
    volume {
      name = "workspace-data"
      persistent_volume_claim {
        claim_name = local.computed_pvc_name
      }
    }
  }
}