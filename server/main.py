"""
iOSCTF Companion Server
FastAPI server providing dynamic challenge endpoints for network-layer attacks.

Run: python main.py
     Access: http://<your-mac-ip>:8000
"""

import hashlib, hmac, base64, time, json, os, logging
from typing import Optional
from datetime import datetime, timedelta

import jwt                          # pip install pyjwt
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect, HTTPException, Header
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn                      # pip install uvicorn

# ─── Config ──────────────────────────────────────────────────────────────────

JWT_SECRET   = "secret123"          # VULN N5: embarrassingly weak
JWT_ALGO     = "HS256"
WS_TOKEN_TTL = 300                  # seconds — N4 replay window
ADMIN_CODE   = "ADMIN_OAUTH_CODE_XYZ"

logging.basicConfig(level=logging.INFO, format="[CTF] %(levelname)s %(message)s")
log = logging.getLogger("iosctf")

# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(title="iOSCTF Companion Server", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Static files (HTML pages for WebView challenges)
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# ─── Health ───────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "server": "iOSCTF", "version": "1.0.0", "timestamp": int(time.time())}

# ─── N1: Cleartext Login ──────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    username: str
    password: str

@app.post("/api/network/login")
def n1_login(body: LoginRequest, request: Request):
    """
    VULN N1: This endpoint is served over HTTP (no TLS).
    The iOS app sends credentials in cleartext — interceptable via Burp.
    Any credentials accepted — the flag is in the response.
    """
    log.info(f"N1 login: user={body.username} pass={body.password} from {request.client.host}")
    return {
        "status": "success",
        "message": f"Welcome, {body.username}",
        "flag": "IOSCTF{N1_http_traffic_in_plaintext}",
        "note": "These credentials were just sent in cleartext HTTP. Check your Burp history."
    }

# ─── N2: No TLS Validation ────────────────────────────────────────────────────

@app.get("/api/network/insecure-data")
def n2_insecure_data():
    """
    VULN N2: The iOS app's URLSession accepts any certificate.
    Burp doesn't need its CA installed — the app will trust it anyway.
    """
    return {
        "status": "success",
        "secret": "This data was sent over HTTPS with no certificate validation",
        "flag": "IOSCTF{N2_any_cert_any_trust}",
        "vuln": "NSURLSession.AuthChallengeDisposition.useCredential with any server trust"
    }

# ─── N3: Certificate Pinning ──────────────────────────────────────────────────

@app.get("/api/network/pinned-data")
def n3_pinned_data():
    """
    This endpoint requires the iOS app to reach it.
    The app implements cert pinning — bypass required (Frida/Objection).
    """
    return {
        "status": "success",
        "flag": "IOSCTF{N3_urlsession_pinning_bypassed}",
        "note": "You bypassed URLSession certificate pinning to reach this."
    }

# ─── N4: WebSocket Token Replay ───────────────────────────────────────────────

class WSTokenRequest(BaseModel):
    token: str
    action: str = "authenticate"

@app.post("/api/ws/challenge")
def n4_http_token(body: WSTokenRequest, request: Request):
    """
    HTTP POST handler for N4 — the iOS app sends the token here (interceptable in Burp).
    Player decodes the token from Burp, then replays via wscat to the WebSocket endpoint.
    """
    auth_header = request.headers.get("authorization", "")
    token = auth_header.replace("Bearer ", "") if auth_header.startswith("Bearer ") else body.token

    log.info(f"N4 HTTP token received: {token[:30]}...")

    if _verify_ws_token(token):
        return {
            "status": "token_valid",
            "hint": "Token accepted. Now replay it via WebSocket: wscat -c ws://<server>:8000/api/ws/challenge then send {\"token\": \"<token>\"}",
            "token_received": token,
            "note": "This token is base64(username:timestamp) — no signing, replayable within 300s"
        }
    return {
        "status": "token_invalid",
        "hint": "Token format: base64(username + ':' + unix_timestamp)"
    }

@app.websocket("/api/ws/challenge")
async def n4_websocket(websocket: WebSocket):
    """
    VULN N4: Auth token = base64(username:timestamp) — no HMAC, replayable within 300s.
    Connect with: wscat -c ws://<server>:8000/api/ws/challenge
    Send: {"token": "<base64_token>"}
    """
    await websocket.accept()
    log.info("N4 WebSocket connected")
    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                token = msg.get("token", "")
                if _verify_ws_token(token):
                    await websocket.send_text(json.dumps({
                        "status": "authenticated",
                        "flag": "IOSCTF{N4_websocket_token_replayed}",
                        "note": "Token was replayed — base64(username:timestamp) has no signing"
                    }))
                else:
                    await websocket.send_text(json.dumps({
                        "status": "rejected",
                        "reason": "Invalid or expired token",
                        "hint": "Token format: base64(username + ':' + unix_timestamp)"
                    }))
            except json.JSONDecodeError:
                await websocket.send_text('{"error": "Invalid JSON"}')
    except WebSocketDisconnect:
        log.info("N4 WebSocket disconnected")

def _verify_ws_token(token: str) -> bool:
    """VULN: Token is just base64(username:timestamp) — no HMAC, no signing."""
    try:
        decoded = base64.b64decode(token).decode()
        parts = decoded.split(":")
        if len(parts) != 2:
            return False
        _, timestamp_str = parts
        ts = int(timestamp_str)
        now = int(time.time())
        # Accept tokens within ±300 seconds — replay window
        return abs(now - ts) <= WS_TOKEN_TTL
    except Exception:
        return False

# ─── N5: JWT Weak Secret ──────────────────────────────────────────────────────

@app.get("/api/auth/token")
def n5_get_token():
    """
    VULN N5: JWT signed with 'secret123' — trivially crackable with hashcat/rockyou.
    GET this token, crack the secret, forge admin:true, POST to /api/auth/verify.
    """
    payload = {
        "user": "ctfuser",
        "admin": False,
        "iat": int(time.time()),
        "exp": int(time.time()) + 3600
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGO)
    return {"token": token, "type": "Bearer", "hint": "HS256 — try cracking this"}

class TokenSubmit(BaseModel):
    token: str

@app.post("/api/auth/verify")
def n5_verify_token(body: TokenSubmit):
    """Submit a forged JWT with admin:true to receive the flag."""
    try:
        payload = jwt.decode(body.token, JWT_SECRET, algorithms=[JWT_ALGO])
        if payload.get("admin") is True:
            return {
                "status": "admin_access_granted",
                "flag": "IOSCTF{N5_jwt_secret_was_secret123}",
                "cracked_secret": JWT_SECRET
            }
        return {"status": "denied", "reason": "Not admin", "hint": "Forge admin: true in the payload"}
    except jwt.ExpiredSignatureError:
        raise HTTPException(400, "Token expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(400, f"Invalid token: {e}")

# ─── N6: SPKI Pinning (deeper) ────────────────────────────────────────────────

@app.get("/api/network/spki-pinned")
def n6_spki_pinned():
    """
    The iOS app implements SPKI hash pinning for this endpoint.
    Bypass requires hooking SecTrustEvaluateWithError at the C level.
    """
    return {
        "flag": "IOSCTF{N6_trustkit_hooked_by_frida}",
        "note": "You bypassed SPKI public key pinning via Frida C-level hook"
    }

# ─── N7: OAuth CSRF (state parameter not validated) ──────────────────────────

# Simulated user store
_oauth_users = {
    "ctfuser": {"code": None, "state": None},
    "admin":   {"code": "ADMIN_OAUTH_CODE_XYZ", "state": "randomstate123"}
}
_issued_codes: dict[str, str] = {}   # code → username

@app.get("/api/oauth/authorize")
def n7_oauth_authorize(client_id: str, redirect_uri: str, state: str, response_type: str = "code"):
    """
    VULN N7: state parameter is echoed back but never validated server-side.
    The redirect_uri is also not validated against registered URIs.
    Manipulate state to receive admin's authorization code.
    """
    log.info(f"N7 OAuth authorize: client={client_id} redirect={redirect_uri} state={state}")

    # VULN: Any redirect_uri accepted — no registration check
    # VULN: state is echoed, never validated for CSRF protection
    code = hashlib.sha256(f"{client_id}{time.time()}".encode()).hexdigest()[:16]

    # VULN: If state contains 'admin', issue code for admin user
    # (Simplified to make the challenge solvable — real vulns are more subtle)
    user = "admin" if "admin" in state else "ctfuser"
    _issued_codes[code] = user

    # In a real OAuth flow this would redirect — here we return JSON for clarity
    return {
        "code": code,
        "state": state,          # echoed, never validated
        "redirect_uri": redirect_uri,  # accepted without validation
        "issued_for": user,
        "hint": "Notice state is echoed. What happens if state contains 'admin'?"
    }

class TokenRequest(BaseModel):
    code: str
    redirect_uri: str
    client_id: str

@app.post("/api/oauth/token")
def n7_oauth_token(body: TokenRequest):
    """Exchange authorization code for access token. redirect_uri not re-validated."""
    user = _issued_codes.pop(body.code, None)
    if not user:
        raise HTTPException(400, "Invalid or expired code")

    # VULN: redirect_uri not compared against the one used in /authorize
    access_token = jwt.encode({"user": user, "exp": int(time.time()) + 3600}, JWT_SECRET, JWT_ALGO)

    response = {"access_token": access_token, "user": user}
    if user == "admin":
        response["flag"] = "IOSCTF{N7_oauth_state_csrf_dance}"
        response["note"] = "You received an admin token by manipulating the OAuth state parameter"
    return response

# ─── Open Redirect (W4) ───────────────────────────────────────────────────────

@app.get("/redirect")
def w4_open_redirect(url: str):
    """
    VULN W4: Open redirect — no validation of destination.
    Used in combination with AASA misconfiguration for universal link hijacking.
    """
    from fastapi.responses import RedirectResponse
    log.info(f"W4 open redirect → {url}")
    return RedirectResponse(url=url)  # VULN: any URL accepted

# ─── AASA (W4) ────────────────────────────────────────────────────────────────

@app.get("/.well-known/apple-app-site-association")
def w4_aasa():
    """
    VULN W4: AASA matches /* — all paths trigger universal links.
    Combined with the open redirect above for the chain.
    """
    return {
        "applinks": {
            "apps": [],
            "details": [{
                "appID": "TEAMID.com.iosctf.app",
                "paths": ["/*"]     # VULN: wildcard — should be specific paths only
            }]
        }
    }

# ─── Static HTML pages for WebView challenges ─────────────────────────────────

def write_static_pages():
    pages = {
        "bridge_page.html": """<!DOCTYPE html><html><head><title>CTF W3</title></head><body>
<h2>Bridge Challenge W3</h2>
<p>This page is loaded in a WKWebView. The native bridge handler 'flagBridge' is exposed.</p>
<p>MITM this page via Burp and inject JavaScript to call the bridge.</p>
<script>
// Injected JS example:
// window.webkit.messageHandlers.flagBridge.postMessage({cmd: 'retrieve', auth: 'ctfuser'});
function receiveFlag(f) { document.body.innerHTML += '<h1 style="color:green">Flag: ' + f + '</h1>'; }
</script></body></html>""",

        "analytics_page.html": """<!DOCTYPE html><html><head><title>CTF W5</title></head><body>
<h2>Analytics SDK Challenge W5</h2>
<p>An 'analytics SDK' bridge is registered in this WebView. It can capture localStorage.</p>
<script>
// The bridge is: window.webkit.messageHandlers.analyticsSDK
// Call: analyticsSDK.postMessage({type: 'capture', target: 'localStorage'})
// The session_token in localStorage is the flag.
function triggerCapture() {
    window.webkit.messageHandlers.analyticsSDK.postMessage({type: 'capture', target: 'localStorage'});
}
document.addEventListener('DOMContentLoaded', function() {
    document.body.innerHTML += '<button onclick="triggerCapture()">Trigger SDK Capture</button>';
});
</script></body></html>""",

        "shared_storage_page.html": """<!DOCTYPE html><html><head><title>CTF W6</title></head><body>
<h2>Shared Storage Challenge W6</h2>
<p>localStorage contains a secret. Shared WKProcessPool means no partition.</p>
<script>
localStorage.setItem('ctf_w6_flag', 'IOSCTF{W6_localstorage_stolen_via_iframe}');
// Inject an iframe via MITM: <iframe src="http://localhost:8000/static/steal.html"></iframe>
// steal.html: parent.postMessage(localStorage.getItem('ctf_w6_flag'), '*')
window.addEventListener('message', function(e) {
    alert('Received from iframe: ' + e.data);
});
</script></body></html>""",

        "steal.html": """<!DOCTYPE html><html><body><script>
// This page is loaded in an iframe injected via MITM
// It reads localStorage from the parent origin due to shared WKProcessPool
try {
    var flag = localStorage.getItem('ctf_w6_flag');
    parent.postMessage(flag || 'not found', '*');
} catch(e) {
    parent.postMessage('error: ' + e.message, '*');
}
</script></body></html>""",

        "chain_page.html": """<!DOCTYPE html><html><head><title>CTF W7 Chain</title></head><body>
<h2>DeepLink Chain Stage 2 — W7</h2>
<p>Stage 2 of 3. This page was loaded via ctfapp://webload. Now call the chainBridge.</p>
<p>Stage 3: chainBridge checks a HMAC. The key is in UserDefaults (found in S1).</p>
<script>
function callChainBridge(hmac) {
    window.webkit.messageHandlers.chainBridge.postMessage({
        message: 'ctf_chain_request',
        hmac: hmac
    });
}
function receiveChainFlag(f) {
    document.body.innerHTML += '<h1 style="color:green">CHAIN COMPLETE: ' + f + '</h1>';
}
// Compute HMAC in Python: hmac.new(key.encode(), 'ctf_chain_request'.encode(), sha256).hexdigest()
</script></body></html>"""
    }

    for filename, content in pages.items():
        path = os.path.join("static", filename)
        if not os.path.exists(path):
            with open(path, "w") as f:
                f.write(content)
            log.info(f"Created static/{filename}")

# ─── Entry point ──────────────────────────────────────────────────────────────

import subprocess, threading, ssl as _ssl, socket

CERT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".ctf_certs")
CERT_FILE = os.path.join(CERT_DIR, "server.pem")
KEY_FILE  = os.path.join(CERT_DIR, "server.key")

def _generate_cert():
    """Auto-generate a self-signed cert for HTTPS (N2/N3 challenges)."""
    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        log.info("Using existing self-signed cert")
        return
    os.makedirs(CERT_DIR, exist_ok=True)
    log.info("Generating self-signed certificate for HTTPS...")
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048",
        "-keyout", KEY_FILE, "-out", CERT_FILE,
        "-days", "365", "-nodes",
        "-subj", "/CN=ctf-server/O=iOSCTF/C=US"
    ], check=True, capture_output=True)
    log.info(f"Cert saved to {CERT_DIR}")

def _get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()

if __name__ == "__main__":
    write_static_pages()
    _generate_cert()

    local_ip = _get_local_ip()
    log.info("iOSCTF Companion Server starting...")
    log.info(f"  HTTP  → http://{local_ip}:8000   (N1, N4, N5, N6, N7)")
    log.info(f"  HTTPS → https://{local_ip}:8443  (N2, N3)")
    log.info(f"  Set '{local_ip}' as server IP in the CTF app.")
    log.info("Active challenge endpoints:")
    for route in app.routes:
        if hasattr(route, "methods"):
            log.info(f"  {list(route.methods)} {route.path}")

    # Run HTTPS on port 8443 in a background thread
    def run_https():
        uvicorn.run(app, host="0.0.0.0", port=8443,
                    ssl_certfile=CERT_FILE, ssl_keyfile=KEY_FILE,
                    log_level="warning")

    https_thread = threading.Thread(target=run_https, daemon=True)
    https_thread.start()

    # Run HTTP on port 8000 in the main thread
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")
