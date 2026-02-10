import os
import time
import subprocess
import webbrowser
import requests
import signal
import sys
from threading import Timer
from flask import Flask, request, render_template_string

# ---------------- CONFIGURATION ----------------
NAMESPACE = "keycloak"
SERVICE_NAME = "keycloak"
LOCAL_PORT = 8080
KEYCLOAK_URL = f"http://localhost:{LOCAL_PORT}"
INITIAL_USER = "admin"
INITIAL_PASS = "admin"
# -----------------------------------------------

app = Flask(__name__)
pf_process = None

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>Keycloak 초기 보안 설정</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f4f6f8; margin: 0; }
        .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); width: 100%; max-width: 400px; }
        h2 { text-align: center; color: #1a1a1a; margin-bottom: 24px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; color: #4a5568; font-weight: 500; }
        input { width: 100%; padding: 12px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box; transition: border-color 0.2s; }
        input:focus { border-color: #3182ce; outline: none; }
        button { width: 100%; padding: 14px; background-color: #3182ce; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 16px; font-weight: 600; transition: background-color 0.2s; }
        button:hover { background-color: #2b6cb0; }
        .note { font-size: 13px; color: #718096; margin-top: 16px; text-align: center; }
        .success { color: #2f855a; text-align: center; padding: 20px; }
        .error { color: #c53030; background: #fff5f5; padding: 10px; border-radius: 6px; margin-bottom: 20px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="card">
        {% if success %}
            <div class="success">
                <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                    <polyline points="22 4 12 14.01 9 11.01"></polyline>
                </svg>
                <h3>변경 완료!</h3>
                <p>관리자 비밀번호가 안전하게 변경되었습니다.</p>
                <p>이제 창을 닫으셔도 됩니다.</p>
            </div>
        {% else %}
            <h2>관리자 비밀번호 설정</h2>
            {% if error %}
                <div class="error">{{ error }}</div>
            {% endif %}
            <form method="POST">
                <div class="form-group">
                    <label>새로운 Username</label>
                    <input type="text" name="username" required placeholder="예: admin" value="{{ initial_user }}">
                </div>
                <div class="form-group">
                    <label>새로운 Password</label>
                    <input type="password" name="password" required placeholder="강력한 비밀번호 입력">
                </div>
                <button type="submit">변경 및 적용</button>
            </form>
            <p class="note">현재 초기 상태(admin/admin)가 감지되어<br>자동으로 실행된 보안 설정 페이지입니다.</p>
        {% endif %}
    </div>
</body>
</html>
"""

def start_port_forward():
    """Kubectl 포트 포워딩을 백그라운드에서 실행"""
    global pf_process
    print(f"[*] Port-forwarding svc/{SERVICE_NAME} to localhost:{LOCAL_PORT}...")
    # 기존 포트 포워딩이 있다면 정리
    subprocess.run(["pkill", "-f", f"port-forward.*{SERVICE_NAME}"], stderr=subprocess.DEVNULL)
    
    cmd = [
        "kubectl", "port-forward", 
        "-n", NAMESPACE, 
        f"svc/{SERVICE_NAME}", 
        f"{LOCAL_PORT}:8080"
    ]
    pf_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)  # 포워딩 연결 대기

def stop_port_forward():
    """포트 포워딩 프로세스 종료"""
    if pf_process:
        pf_process.terminate()
        print("[*] Port-forwarding stopped.")

def get_admin_token(username, password):
    """Keycloak Admin 토큰 발급"""
    url = f"{KEYCLOAK_URL}/realms/master/protocol/openid-connect/token"
    data = {"client_id": "admin-cli", "username": username, "password": password, "grant_type": "password"}
    try:
        resp = requests.post(url, data=data, timeout=5)
        if resp.status_code == 200:
            return resp.json().get('access_token')
    except Exception:
        pass
    return None

def change_password(token, current_username, new_username, new_password):
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    
    # 1. 사용자 ID 조회
    users_url = f"{KEYCLOAK_URL}/admin/realms/master/users"
    users = requests.get(users_url, headers=headers, params={"username": current_username}).json()
    
    if not users:
        return False, "사용자를 찾을 수 없습니다."
    
    user_id = users[0]['id']
    
    # 2. 정보 업데이트
    update_data = {
        "username": new_username,
        "credentials": [{"type": "password", "value": new_password, "temporary": False}]
    }
    resp = requests.put(f"{users_url}/{user_id}", headers=headers, json=update_data)
    
    return resp.status_code == 204, "업데이트 실패"

def shutdown_server():
    """1초 후 서버 종료"""
    def _shutdown():
        os.kill(os.getpid(), signal.SIGINT)
    Timer(1.0, _shutdown).start()

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        new_user = request.form.get("username")
        new_pass = request.form.get("password")
        
        token = get_admin_token(INITIAL_USER, INITIAL_PASS)
        if token:
            success, msg = change_password(token, INITIAL_USER, new_user, new_pass)
            if success:
                shutdown_server()
                return render_template_string(HTML_TEMPLATE, success=True)
            return render_template_string(HTML_TEMPLATE, error=msg, initial_user=new_user)
        else:
            return render_template_string(HTML_TEMPLATE, error="세션이 만료되었거나 이미 비밀번호가 변경되었습니다.", initial_user=new_user)
            
    return render_template_string(HTML_TEMPLATE, error=None, initial_user=INITIAL_USER)

def check_if_secure():
    """초기 비밀번호로 로그인이 가능한지 확인"""
    print("[*] Checking Keycloak security status...")
    token = get_admin_token(INITIAL_USER, INITIAL_PASS)
    if not token:
        print("[OK] Default credentials (admin/admin) are NOT valid. Keycloak is secure.")
        return True # Secure
    else:
        print("[!] Default credentials found. Initiating security setup...")
        return False # Not Secure

def main():
    try:
        start_port_forward()
        if check_if_secure():
            return # 이미 보안 설정됨
            
        print("[*] Launching browser for admin setup...")
        webbrowser.open(f"http://localhost:5000")
        app.run(port=5000)
    finally:
        stop_port_forward()

if __name__ == "__main__":
    main()
