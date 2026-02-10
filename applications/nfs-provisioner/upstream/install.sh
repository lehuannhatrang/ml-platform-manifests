#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# =========================
# Configuration & Defaults
# =========================
NAMESPACE="kube-system"
RELEASE_NAME="nfs-subdir-external-provisioner"
REPO_NAME="nfs-subdir-external-provisioner"
REPO_URL="https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
CHART="${REPO_NAME}/nfs-subdir-external-provisioner"

STORAGE_CLASS_NAME="nfs-client"
MAKE_DEFAULT="auto"     # auto|true|false
                        # auto: if no default SC exists -> true, else false
CHART_VERSION=""        # optional: set a specific version, e.g., "4.0.18"
WAIT_TIMEOUT="180s"
SMOKE_TEST="true"
SMOKE_TEST_NAMESPACE_PREFIX="nfs-smoke-test"

# User Inputs (load from env vars or defaults)
NFS_SERVER="${NFS_SERVER:-}"
NFS_PATH="${NFS_PATH:-/srv/nfs/kubedata}"

# =========================
# Helpers
# =========================
log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage:
  NFS_SERVER=<ip_or_host> NFS_PATH=<export_path> $0 [options]

  If NFS_SERVER is not provided, script attempts to auto-detect Control Plane IP.
  If NFS_PATH is not provided, it defaults to /srv/nfs/kubedata.

Options:
  --namespace <ns>            (default: ${NAMESPACE})
  --release <name>            (default: ${RELEASE_NAME})
  --storage-class-name <name> (default: ${STORAGE_CLASS_NAME})
  --make-default <auto|true|false> (default: ${MAKE_DEFAULT})
  --chart-version <version>   (default: ${CHART_VERSION:-latest})
  --wait-timeout <duration>   (default: ${WAIT_TIMEOUT})
  --smoke-test <true|false>   (default: ${SMOKE_TEST})
  --smoke-test-ns-prefix <p>  (default: ${SMOKE_TEST_NAMESPACE_PREFIX})
  -h|--help                   Show this help message

Examples:
  # Install with auto-discovery of default storage class
  NFS_SERVER=192.168.1.100 NFS_PATH=/data/k8s $0

  # Force this storage class to be default (WARNING: will unset existing default)
  NFS_SERVER=192.168.1.100 NFS_PATH=/data/k8s $0 --make-default true
EOF
}

on_err() {
  local line="$1"
  die "Script failed at line ${line}. Check logs above."
}
trap 'on_err $LINENO' ERR

require_arg() {
  [[ $# -ge 2 && -n "${2:-}" ]] || die "Missing value for $1"
}

check_permission() {
  local verb="$1"
  local resource="$2"
  local ns="${3:-}"
  
  local args=(auth can-i "$verb" "$resource")
  if [[ -n "$ns" ]]; then
    args+=(-n "$ns")
  fi
  
  if ! kubectl "${args[@]}" >/dev/null 2>&1; then
     if [[ -n "$ns" ]]; then
        return 1
     else
        return 1
     fi
  fi
  return 0
}

# Wrapper for check_permission that dies on failure
verify_permission_or_die() {
    if ! check_permission "$@"; then
        local verb="$1"
        local resource="$2"
        local ns="${3:-}"
        if [[ -n "$ns" ]]; then
             die "Insufficient permission: Cannot '$verb' '$resource' in namespace '$ns'. Check RBAC."
        else
             die "Insufficient permission: Cannot '$verb' '$resource' (cluster-scoped). Check RBAC."
        fi
    fi
}

unset_default_sc() {
  local sc="$1"
  local strict="${2:-false}"
  
  log "Unsetting existing default StorageClass: $sc"
  if ! kubectl patch sc "$sc" --type=merge -p \
    '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false","storageclass.beta.kubernetes.io/is-default-class":"false"}}}' \
    >/dev/null; then
    
    if [[ "$strict" == "true" ]]; then
      die "Failed to unset default status for StorageClass '$sc'. Aborting to prevent split-brain defaults."
    else
      warn "Failed to unset default status for StorageClass '$sc'. Manual intervention may be required."
    fi
  fi
}

cleanup_smoke_test() {
    # Only run if smoke test vars and namespace are set
    if [[ -n "${TEST_NAMESPACE:-}" ]]; then
        log "Cleaning up smoke test namespace '${TEST_NAMESPACE}'..."
        kubectl delete ns "${TEST_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    fi
}

# =========================
# Arg parsing
# =========================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) require_arg "$@"; NAMESPACE="$2"; shift 2;;
    --release) require_arg "$@"; RELEASE_NAME="$2"; shift 2;;
    --storage-class-name) require_arg "$@"; STORAGE_CLASS_NAME="$2"; shift 2;;
    --make-default) require_arg "$@"; MAKE_DEFAULT="$2"; shift 2;;
    --chart-version) require_arg "$@"; CHART_VERSION="$2"; shift 2;;
    --wait-timeout) require_arg "$@"; WAIT_TIMEOUT="$2"; shift 2;;
    --smoke-test) require_arg "$@"; SMOKE_TEST="$2"; shift 2;;
    --smoke-test-ns-prefix) require_arg "$@"; SMOKE_TEST_NAMESPACE_PREFIX="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (use --help)";;
  esac
done

# =========================
# 1. Validation (Fail-Fast)
# =========================
command -v helm >/dev/null 2>&1 || die "helm not found."
command -v kubectl >/dev/null 2>&1 || die "kubectl not found."

# Check for NFS client utilities on the CURRENT node (where script runs)
# Note: In a real cluster, ALL nodes need this. We can only check the current one easily.
if ! command -v showmount >/dev/null 2>&1 && ! command -v mount.nfs >/dev/null 2>&1; then
    warn "NFS client utilities (nfs-common or nfs-utils) not found on this machine."
    warn "Please ensure 'nfs-common' (Debian/Ubuntu) or 'nfs-utils' (RHEL/CentOS) is installed on ALL KUBERNETES NODES."
    warn "Example: sudo apt-get update && sudo apt-get install -y nfs-common"
    # We warn but do not die, as this machine might just be a bastion/client, 
    # though usually it's good to have it for troubleshooting (showmount).
fi

# Auto-detect NFS_SERVER if not provided
if [[ -z "${NFS_SERVER}" ]]; then
    log "NFS_SERVER not provided. Attempting to detect Control Plane IP..."
    # Try to get IP of the node with control-plane label
    detected_ip=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
    
    if [[ -z "${detected_ip}" ]]; then
        # Fallback: try master label (older versions)
        detected_ip=$(kubectl get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
    fi

    if [[ -n "${detected_ip}" ]]; then
        NFS_SERVER="${detected_ip}"
        log "Set NFS_SERVER to Control Plane IP: ${NFS_SERVER}"
    else
        warn "Failed to auto-detect Control Plane IP."
    fi
fi

# Ensure inputs are provided
if [[ -z "${NFS_SERVER}" ]]; then
    die "NFS_SERVER is required.\nRun with: NFS_SERVER=x.x.x.x $0 ..."
fi
if [[ -z "${NFS_PATH}" ]]; then
    die "NFS_PATH is required.\nRun with: NFS_PATH=/your/path $0 ..."
fi

# Fail-fast on placeholders
if [[ "${NFS_SERVER}" == "192.168.x.x" ]]; then
    die "NFS_SERVER is set to placeholder (192.168.x.x). Please provide a valid IP."
fi
if [[ "${NFS_PATH}" == "/path/to/nfs/share" ]]; then
    die "NFS_PATH is set to placeholder (/path/to/nfs/share). Please provide a valid path."
fi
if [[ "${NFS_PATH}" != /* ]]; then
    die "NFS_PATH must be an absolute path (start with /)."
fi

# Validate flags
case "${MAKE_DEFAULT}" in
  auto|true|false) ;;
  *) die "--make-default must be one of: auto, true, false" ;;
esac

case "${SMOKE_TEST}" in
  true|false) ;;
  *) die "--smoke-test must be true|false" ;;
esac


# =========================
# 2. Pre-flight Checks (RBAC & Network)
# =========================

log "Checking RBAC permissions..."
verify_permission_or_die "get" "storageclass"

# Conditional Permission Checks
if ! kubectl get sc "${STORAGE_CLASS_NAME}" >/dev/null 2>&1; then
    verify_permission_or_die "create" "storageclass"
fi

# We check patch permission if we are likely to change defaults. 
# 'auto' might change default if none exists, but wouldn't patch existing ones.
# 'true' definitely patches existing ones.
if [[ "${MAKE_DEFAULT}" == "true" ]]; then
    verify_permission_or_die "patch" "storageclass"
fi

if [[ "${SMOKE_TEST}" == "true" ]]; then
    verify_permission_or_die "create" "namespace"
    # Detailed RBAC for smoke test resources is checked AFTER namespace creation
fi

log "Checking cluster access..."
kubectl cluster-info >/dev/null 2>&1 || die "Cannot access cluster (kubectl cluster-info failed). Check kubeconfig."

# Network Checks (Best Effort)
if command -v nc >/dev/null 2>&1; then
    log "Checking NFS port connectivity..."
    if ! nc -z -w 2 "${NFS_SERVER}" 2049; then
        warn "Could not connect to NFS Server ${NFS_SERVER}:2049 via TCP. Installation may fail or hang."
    fi
fi

# Ensure namespace exists
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  log "Creating namespace: ${NAMESPACE}"
  verify_permission_or_die "create" "namespace"
  kubectl create ns "${NAMESPACE}"
fi

# =========================
# 3. Default StorageClass Analysis
# =========================
log "Analyzing existing default StorageClasses..."

# Use mapfile to safely read lines into an array
existing_default_names=()
mapfile -t existing_default_names < <(kubectl get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}{range .items[?(@.metadata.annotations.storageclass\.beta\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | sort -u | sed '/^$/d')

default_sc_count=${#existing_default_names[@]}
effective_make_default="${MAKE_DEFAULT}"

if [[ "${MAKE_DEFAULT}" == "auto" ]]; then
  if [[ "$default_sc_count" -eq 0 ]]; then
    effective_make_default="true"
    log "No default StorageClass found. Will set '${STORAGE_CLASS_NAME}' as default."
    # If we are setting default, we need patch permission on the new SC (implicit in create/update usually)
    # or if we are upgrading an existing one. For safety, let's verify patch.
    if kubectl get sc "${STORAGE_CLASS_NAME}" >/dev/null 2>&1; then
        verify_permission_or_die "patch" "storageclass"
    fi
  else
    effective_make_default="false"
    # Fail if multiple defaults exist in auto mode (Strict safety)
    if [[ "$default_sc_count" -gt 1 ]]; then
         warn "Multiple default StorageClasses found ($default_sc_count):"
         printf '%s\n' "${existing_default_names[@]}" | sed 's/^/  - /' >&2
         die "Cluster is in an invalid state (multiple defaults). Please resolve manually or use --make-default true to force overwrite."
    else
         first_default="${existing_default_names[0]}"
         log "Existing default StorageClass detected: '$first_default'. Will NOT set '${STORAGE_CLASS_NAME}' as default."
    fi
  fi
elif [[ "${MAKE_DEFAULT}" == "true" ]]; then
    # Force mode: Unset ALL existing defaults that are not our target
    if [[ "$default_sc_count" -gt 0 ]]; then
        warn "Force setting default. Unsetting existing default StorageClasses..."
        for sc in "${existing_default_names[@]}"; do
             if [[ -n "$sc" && "$sc" != "${STORAGE_CLASS_NAME}" ]]; then
                 unset_default_sc "$sc" "true"  # Pass "true" for strict mode
             fi
        done
    fi
fi

# =========================
# 4. Idempotency & Conflict Checks
# =========================
if kubectl get sc "${STORAGE_CLASS_NAME}" >/dev/null 2>&1; then
  # Check ownership
  owner_release="$(kubectl get sc "${STORAGE_CLASS_NAME}" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true)"
  owner_ns="$(kubectl get sc "${STORAGE_CLASS_NAME}" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || true)"
  
  # Fail if it exists but belongs to another release/namespace
  if [[ -n "$owner_release" ]]; then
      if [[ "${owner_release}" != "${RELEASE_NAME}" || "${owner_ns}" != "${NAMESPACE}" ]]; then
        die "StorageClass '${STORAGE_CLASS_NAME}' exists and is managed by a different Helm release (${owner_release}/${owner_ns}).\nAborting to avoid conflict. Use --storage-class-name to specify a different name."
      fi
  else
      # Exists but no helm annotations - likely manually created
      die "StorageClass '${STORAGE_CLASS_NAME}' exists but does not appear to be managed by Helm.\nAborting to avoid ownership conflict. Choose another name or delete the SC."
  fi
fi

# =========================
# 5. Helm Install / Upgrade
# =========================
log "Adding/updating Helm repo..."
helm repo add "${REPO_NAME}" "${REPO_URL}" --force-update >/dev/null
if ! helm repo update >/dev/null; then
    warn "Helm repo update failed."
fi

# Pre-flight check: can we find the chart?
chart_verify_cmd=(helm show chart "${CHART}")
if [[ -n "${CHART_VERSION}" ]]; then
    chart_verify_cmd+=(--version "${CHART_VERSION}")
fi

if ! "${chart_verify_cmd[@]}" >/dev/null 2>&1; then
   warn "Cannot resolve chart '${CHART}' from repo."
   warn "If you are in an air-gapped environment, ensure the chart is cached locally."
   warn "Otherwise, check your network connection and repo URL."
   die "Chart resolution failed."
fi

log "Deploying Helm release: ${RELEASE_NAME} (ns: ${NAMESPACE})..."

helm_args=(
  upgrade --install "${RELEASE_NAME}" "${CHART}"
  --namespace "${NAMESPACE}"
  --create-namespace
  --set-string "nfs.server=${NFS_SERVER}"
  --set-string "nfs.path=${NFS_PATH}"
  --set-string "storageClass.name=${STORAGE_CLASS_NAME}"
  --set "storageClass.defaultClass=${effective_make_default}"
  --wait
  --timeout "${WAIT_TIMEOUT}"
  --atomic
)

if [[ -n "${CHART_VERSION}" ]]; then
  helm_args+=(--version "${CHART_VERSION}")
fi

helm "${helm_args[@]}"

# =========================
# 6. Verification
# =========================
# Find deployment by label to be robust against name changes
# 1. Try standard chart labels (new charts)
deploy_name="$(
  kubectl -n "${NAMESPACE}" get deploy \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=nfs-subdir-external-provisioner" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"

# 2. Fallback: Try legacy labels (older charts)
if [[ -z "${deploy_name}" ]]; then
    deploy_name="$(kubectl -n "${NAMESPACE}" get deploy -l "app=nfs-subdir-external-provisioner,release=${RELEASE_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

# 3. Fallback: Try just 'app' label (broadest match)
if [[ -z "${deploy_name}" ]]; then
    deploy_name="$(kubectl -n "${NAMESPACE}" get deploy -l "app=nfs-subdir-external-provisioner" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

# 4. Last Resort: Guess name based on Release Name (standard Helm convention)
if [[ -z "${deploy_name}" ]]; then
    potential_name="${RELEASE_NAME}-nfs-subdir-external-provisioner"
    if kubectl -n "${NAMESPACE}" get deploy "${potential_name}" >/dev/null 2>&1; then
        deploy_name="${potential_name}"
    fi
fi

if [[ -n "${deploy_name}" ]]; then
    log "Verifying deployment rollout: ${deploy_name}"
    kubectl -n "${NAMESPACE}" rollout status "deployment/${deploy_name}" --timeout="${WAIT_TIMEOUT}"
else
    warn "Could not find deployment by common labels. Skipping rollout status verify (Helm --wait passed)."
fi

log "Verifying StorageClass..."
if kubectl get sc "${STORAGE_CLASS_NAME}" >/dev/null 2>&1; then
    log "StorageClass '${STORAGE_CLASS_NAME}' is present."
else
    die "StorageClass '${STORAGE_CLASS_NAME}' was not found after installation."
fi

# Verify Default Status if expected
if [[ "${effective_make_default}" == "true" ]]; then
   # Check standard annotation
   is_def=$(kubectl get sc "${STORAGE_CLASS_NAME}" -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null || true)
   
   if [[ "$is_def" != "true" ]]; then
       warn "Expected StorageClass '${STORAGE_CLASS_NAME}' to be default, but annotation is '${is_def}'."
       warn "Check if your cluster supports automatic default class assignment."
   else
       log "Verified: StorageClass '${STORAGE_CLASS_NAME}' is successfully marked as default."
   fi
fi

# =========================
# 7. Smoke Test
# =========================
if [[ "${SMOKE_TEST}" == "true" ]]; then
  # Use a separate temporary namespace for smoke testing to avoid policy issues in kube-system
  TEST_NAMESPACE="${SMOKE_TEST_NAMESPACE_PREFIX}-${RANDOM}"
  TEST_PVC="nfs-smoke-pvc-${RANDOM}"
  TEST_POD="nfs-smoke-pod-${RANDOM}"
  
  log "Setting up smoke test in separate namespace: ${TEST_NAMESPACE}..."
  
  # Register cleanup trap for smoke test namespace
  trap cleanup_smoke_test EXIT
  
  kubectl create ns "${TEST_NAMESPACE}" >/dev/null

  # Strict Smoke Test RBAC Checks
  log "Verifying permissions in smoke test namespace..."
  verify_permission_or_die "create" "persistentvolumeclaims" "${TEST_NAMESPACE}"
  verify_permission_or_die "create" "pods" "${TEST_NAMESPACE}"
  # We need to read logs to verify success
  verify_permission_or_die "get" "pods" "${TEST_NAMESPACE}" 
  verify_permission_or_die "get" "pods/log" "${TEST_NAMESPACE}"

  cat <<EOF | kubectl apply -n "${TEST_NAMESPACE}" -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${TEST_PVC}
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: ${STORAGE_CLASS_NAME}
  resources:
    requests:
      storage: 1Mi
EOF

  log "Waiting for PVC '${TEST_PVC}' to be Bound..."
  # Wait loop
  bound=false
  for i in {1..30}; do
    phase="$(kubectl get pvc "${TEST_PVC}" -n "${TEST_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "${phase}" == "Bound" ]]; then
        bound=true
        break
    fi
    sleep 2
  done

  if [[ "$bound" != "true" ]]; then
      # Debug info
      warn "PVC binding timeout."
      kubectl describe pvc "${TEST_PVC}" -n "${TEST_NAMESPACE}" || true
      die "Smoke test failed: PVC '${TEST_PVC}' did not bind within time limit."
  fi

  log "Creating test Pod to verify mount..."
  cat <<EOF | kubectl apply -n "${TEST_NAMESPACE}" -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${TEST_POD}
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: busybox
    # Write, read, and exit successfully.
    command: ["sh","-c","echo 'NFS Test OK' > /data/test.txt && cat /data/test.txt"]
    volumeMounts:
    - name: vol
      mountPath: /data
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: ${TEST_PVC}
EOF

  log "Waiting for Pod '${TEST_POD}' to Succeed..."
  
  # Wait for Succeeded directly. This avoids the "Ready" race condition for short-lived pods.
  if kubectl -n "${TEST_NAMESPACE}" wait --for=condition=Succeeded "pod/${TEST_POD}" --timeout="${WAIT_TIMEOUT}" >/dev/null 2>&1; then
       log "Pod '${TEST_POD}' Succeeded. Reading logs..."
       logs=$(kubectl -n "${TEST_NAMESPACE}" logs "${TEST_POD}" || true)
       
       if [[ "$logs" == *"NFS Test OK"* ]]; then
           log "Smoke test PASSED: Data written and read from NFS volume."
       else
           warn "Smoke test UNCERTAIN: Pod Succeeded but output unexpected: '$logs'"
       fi
  else
      # Failure diagnosis
      log "Smoke test Pod failed to Succeed within timeout."
      kubectl -n "${TEST_NAMESPACE}" describe pod "${TEST_POD}" || true
      kubectl -n "${TEST_NAMESPACE}" logs "${TEST_POD}" || true
      die "Smoke test failed."
  fi

  # Cleanup logic is handled by trap, but we can call it explicitly for clean exit
  trap - EXIT
  cleanup_smoke_test
fi

log "----------------------------------------------------------------"
log "Installation Successful!"
log "Release: ${RELEASE_NAME}"
log "Namespace: ${NAMESPACE}"
log "StorageClass: ${STORAGE_CLASS_NAME} (Default: ${effective_make_default})"
log "----------------------------------------------------------------"
