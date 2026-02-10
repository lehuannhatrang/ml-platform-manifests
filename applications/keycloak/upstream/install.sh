#!/bin/bash
set -e

# 스크립트 위치 기준 경로 설정
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
KEYCLOAK_BASE="$REPO_ROOT/applications/keycloak/base"
MANAGEMENT_DIR="$REPO_ROOT/applications/keycloak/management"

echo "==============================================="
echo "🛠️  Keycloak Installation & Auto-Security Setup"
echo "==============================================="

# 1. 매니페스트 배포
echo "[1/4] Applying Kubernetes Manifests..."
# Check if base directory exists, if not warn the user but proceed (or assume user knows what they are doing)
# However, the user provided this script specifically.
kubectl apply -k "$KEYCLOAK_BASE"

# 2. 파드 준비 상태 대기 (타임아웃 5분)
echo "[2/4] Waiting for Keycloak Pod to be READY..."
echo "      (This usually takes 1-2 minutes)"
kubectl rollout status statefulset/keycloak -n keycloak --timeout=300s

# 3. Python 가상환경 설정 (시스템 오염 방지)
echo "[3/4] Setting up local environment for security script..."
if [ ! -d "$MANAGEMENT_DIR/.venv" ]; then
    python3 -m venv "$MANAGEMENT_DIR/.venv"
fi
source "$MANAGEMENT_DIR/.venv/bin/activate"
pip install -r "$MANAGEMENT_DIR/requirements.txt" --quiet --disable-pip-version-check

# 4. 보안 설정 스크립트 자동 실행
echo "[4/4] Checking Security Status..."
python3 "$MANAGEMENT_DIR/auto_secure.py"

echo "==============================================="
echo "✅  Keycloak installation and setup completed!"
echo "==============================================="
