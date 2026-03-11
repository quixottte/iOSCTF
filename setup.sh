#!/bin/bash
# setup.sh — iOSCTF project bootstrap
# Run this once after cloning the repository.

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          iOSCTF Setup                ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ── 1. Check Xcode ────────────────────────────────────────────────────────────
if ! command -v xcode-select &>/dev/null; then
    echo -e "${RED}✗ Xcode not found. Install from the App Store.${NC}"; exit 1
fi
XCODE_PATH=$(xcode-select -p)
echo -e "${GREEN}✓${NC} Xcode: ${XCODE_PATH}"

# ── 2. Check / Install Homebrew ──────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo -e "${RED}✗ Homebrew not found. Install from https://brew.sh${NC}"; exit 1
fi
echo -e "${GREEN}✓${NC} Homebrew installed"

# ── 3. Install XcodeGen ──────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    echo -e "${YELLOW}  Installing XcodeGen...${NC}"
    brew install xcodegen
fi
echo -e "${GREEN}✓${NC} XcodeGen: $(xcodegen --version 2>&1 | head -1)"

# ── 4. Generate .xcodeproj ───────────────────────────────────────────────────
echo -e "${YELLOW}  Generating CTFApp.xcodeproj...${NC}"
xcodegen generate
echo -e "${GREEN}✓${NC} CTFApp.xcodeproj generated"

# ── 5. Companion server ─────────────────────────────────────────────────────
echo -e "${YELLOW}  Setting up companion server...${NC}"
cd server
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate
pip install -q -r requirements.txt
deactivate
echo -e "${GREEN}✓${NC} Server dependencies installed"
cd ..

# ── 6. Print next steps ─────────────────────────────────────────────────────
MAC_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Open the project:"
echo -e "     ${CYAN}open CTFApp.xcodeproj${NC}"
echo ""
echo "  2. In Xcode:"
echo "     • Select your iPhone as the run destination"
echo "     • Signing & Capabilities → Team → your Apple ID"
echo "     • Change Bundle ID → com.$(whoami).iosctf"
echo "     • Cmd+R to build and run"
echo ""
echo "  3. On iPhone (first time only):"
echo "     Settings → General → VPN & Device Management → Trust your Apple ID"
echo ""
echo "  4. Start the companion server:"
echo -e "     ${CYAN}cd server && source .venv/bin/activate && python main.py${NC}"
echo ""
echo -e "  Your Mac IP: ${YELLOW}${MAC_IP}${NC}"
echo "  Enter this in the CTF app → Server Setup → ${MAC_IP}"
echo ""
echo "  Server ports:"
echo "    HTTP  → :8000  (N1, N4, N5, N7, WebView pages)"
echo "    HTTPS → :8443  (N2, N3, N6 — self-signed cert auto-generated)"
echo ""
echo -e "  ${YELLOW}⚠  This app is intentionally insecure. Use only on research devices.${NC}"
echo ""
