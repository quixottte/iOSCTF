#!/bin/bash
# build_ipa.sh — Build a re-signable IPA for distribution
# Run this on your Mac after the project builds successfully in Xcode.
#
# The resulting IPA can be sideloaded on any iPhone using:
#   - AltStore (macOS/Windows)
#   - Sideloadly (macOS/Windows)
#   - 3uTools (Windows)
#   - TrollStore (jailbroken — no expiry)
#
# Usage:
#   chmod +x build_ipa.sh
#   ./build_ipa.sh

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SCHEME="CTFApp"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build_ipa"
OUTPUT_IPA="${PROJECT_DIR}/CTFApp.ipa"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       iOSCTF — Build IPA             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ── Check prerequisites ──────────────────────────────────────────────────────

if ! command -v xcodebuild &>/dev/null; then
    echo -e "${RED}✗ xcodebuild not found. Install Xcode from the App Store.${NC}"
    exit 1
fi

if [ ! -f "${PROJECT_DIR}/project.yml" ]; then
    echo -e "${RED}✗ project.yml not found. Run this from the iOSCTF root directory.${NC}"
    exit 1
fi

# ── Generate project if needed ───────────────────────────────────────────────

if [ ! -d "${PROJECT_DIR}/CTFApp.xcodeproj" ]; then
    echo -e "${YELLOW}  Generating Xcode project...${NC}"
    if ! command -v xcodegen &>/dev/null; then
        echo -e "${RED}✗ XcodeGen not found. Install: brew install xcodegen${NC}"
        exit 1
    fi
    cd "${PROJECT_DIR}" && xcodegen generate
    echo -e "${GREEN}✓${NC} Project generated"
fi

# ── Clean previous build ────────────────────────────────────────────────────

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ── Build archive ────────────────────────────────────────────────────────────

echo -e "${YELLOW}  Building ${SCHEME} for iOS device (arm64)...${NC}"
echo "  This may take a minute..."
echo ""

xcodebuild archive \
    -project "${PROJECT_DIR}/CTFApp.xcodeproj" \
    -scheme "${SCHEME}" \
    -destination "generic/platform=iOS" \
    -archivePath "${BUILD_DIR}/${SCHEME}.xcarchive" \
    -allowProvisioningUpdates \
    CODE_SIGN_IDENTITY="-" \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -5

# Check if archive succeeded
if [ ! -d "${BUILD_DIR}/${SCHEME}.xcarchive" ]; then
    echo ""
    echo -e "${YELLOW}  Archive with ad-hoc failed. Trying with your signing identity...${NC}"
    echo ""

    xcodebuild archive \
        -project "${PROJECT_DIR}/CTFApp.xcodeproj" \
        -scheme "${SCHEME}" \
        -destination "generic/platform=iOS" \
        -archivePath "${BUILD_DIR}/${SCHEME}.xcarchive" \
        -allowProvisioningUpdates \
        2>&1 | tail -5
fi

if [ ! -d "${BUILD_DIR}/${SCHEME}.xcarchive" ]; then
    echo -e "${RED}✗ Build failed. Make sure the project builds in Xcode first.${NC}"
    echo "  Open CTFApp.xcodeproj, configure signing, and verify it builds."
    rm -rf "${BUILD_DIR}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Archive built"

# ── Extract .app from archive ────────────────────────────────────────────────

APP_PATH="${BUILD_DIR}/${SCHEME}.xcarchive/Products/Applications/${SCHEME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}✗ ${SCHEME}.app not found in archive.${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
fi

# ── Package into IPA ────────────────────────────────────────────────────────

echo -e "${YELLOW}  Packaging IPA...${NC}"

PAYLOAD_DIR="${BUILD_DIR}/Payload"
mkdir -p "${PAYLOAD_DIR}"
cp -r "${APP_PATH}" "${PAYLOAD_DIR}/"

cd "${BUILD_DIR}"
zip -qr "${OUTPUT_IPA}" Payload/

# ── Cleanup ──────────────────────────────────────────────────────────────────

rm -rf "${BUILD_DIR}"

# ── Done ─────────────────────────────────────────────────────────────────────

FILE_SIZE=$(du -h "${OUTPUT_IPA}" | cut -f1)

echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  IPA built successfully!${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo -e "  File: ${CYAN}${OUTPUT_IPA}${NC}"
echo -e "  Size: ${FILE_SIZE}"
echo ""
echo "  Sideloading options:"
echo ""
echo "  macOS:"
echo "    • AltStore — https://altstore.io"
echo "    • Sideloadly — https://sideloadly.io"
echo ""
echo "  Windows:"
echo "    • Sideloadly — https://sideloadly.io"
echo "    • 3uTools — https://www.3u.com"
echo ""
echo "  Jailbroken (no expiry):"
echo "    • TrollStore — install directly, no re-signing needed"
echo "    • AppSync Unified — install via Filza"
echo ""
echo -e "  ${YELLOW}Note: Free Apple ID sideloads expire after 7 days.${NC}"
echo -e "  ${YELLOW}TrollStore users get permanent installation.${NC}"
echo ""
