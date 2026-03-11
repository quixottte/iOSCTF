# iOSCTF

**A deliberately vulnerable iOS application for learning iOS penetration testing, mobile security research, and bug bounty preparation.**

30 challenges across 4 categories — from reading plaintext secrets in NSUserDefaults to chaining deep links through WebView JS bridges. Built for security researchers who learn by breaking things.

> **Warning:** This app is intentionally insecure. Only install on dedicated research devices. Never deploy on devices with personal or sensitive data.

---

## Quick Start

### Prerequisites

| Tool | Required For | Install |
|------|-------------|---------|
| macOS with **Xcode 15+** | Building the app | App Store |
| **XcodeGen** | Generating `.xcodeproj` from `project.yml` | `brew install xcodegen` |
| **Python 3.10+** | Companion server | `brew install python` |
| **Homebrew** | Installing tools | [brew.sh](https://brew.sh) |
| iOS device (jailbroken recommended) | Full challenge set | 18 of 30 challenges work without jailbreak |

### One-Command Setup

```bash
git clone https://github.com/quixottte/iOSCTF.git
cd iOSCTF
chmod +x setup.sh && ./setup.sh
```

This installs XcodeGen (if missing), generates the Xcode project, and sets up the companion server virtualenv.

### Pre-built IPA (No Xcode Required)

For Windows/Linux users or anyone who doesn't want to build from source:

1. Download `CTFApp.ipa` from [Releases](https://github.com/quixottte/iOSCTF/releases/)
2. Sideload onto your iPhone using one of these tools:

| Tool | Platform | Link | Notes |
|------|----------|------|-------|
| **Sideloadly** | Windows / macOS | [sideloadly.io](https://sideloadly.io) | Free, needs Apple ID |
| **AltStore** | Windows / macOS | [altstore.io](https://altstore.io) | Auto re-signs every 7 days |
| **3uTools** | Windows | [3u.com](https://www.3u.com) | Free, GUI-based |
| **TrollStore** | Jailbroken iOS | [GitHub](https://github.com/opa334/TrollStore) | Permanent install, no expiry |

> **Note:** Sideloading with a free Apple ID gives you a 7-day certificate. After that you need to re-sideload. TrollStore (jailbroken devices) installs permanently with no expiry.

3. You still need the **companion server** running on your network — see [Companion Server Setup](#companion-server-setup) below.

### Manual Setup

**Step 1 — Generate the Xcode project:**

```bash
brew install xcodegen        # skip if already installed
cd iOSCTF
xcodegen generate
open CTFApp.xcodeproj
```

**Step 2 — Configure signing in Xcode:**

1. Select **CTFApp** target → **Signing & Capabilities**
2. Team → sign in with your **Apple ID** (free Personal Team works)
3. Change Bundle Identifier to something unique: `com.YOURNAME.iosctf`
4. Connect your iPhone via USB, select it as the run destination
5. **Cmd+R** to build and run

**Step 3 — Trust the developer certificate on iPhone:**

Settings → General → VPN & Device Management → tap your Apple ID → Trust

> Free Apple ID certificates expire after 7 days. Rebuild from Xcode to re-sign, or use AltStore for automatic re-signing.

**Step 4 — Start the companion server:**

<a id="companion-server-setup"></a>

The companion server is required for 15 of 30 challenges (all Network + some WebView). It runs on any machine on the same Wi-Fi as your iPhone — macOS, Windows, or Linux.

**macOS:**

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

**Windows:**

```powershell
cd server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

**Linux:**

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 main.py
```

The server starts on:
- **HTTP** → `http://YOUR_MAC_IP:8000` (N1, N4, N5, N7)
- **HTTPS** → `https://YOUR_MAC_IP:8443` (N2, N3, N6) — auto-generates a self-signed cert on first run

**Step 5 — Connect the app to the server:**

In the CTF app → tap the **ℹ️ icon** → **Server Setup** → enter your Mac's local IP → **Test Connection**

Find your Mac IP: `ipconfig getifaddr en0`

---

## Intercepting Traffic (Burp Suite)

Most network challenges require a proxy. Configure your iPhone to route through Burp:

1. On Mac: Burp Suite → Proxy → Options → listen on **all interfaces**, port **8080**
2. On iPhone: Settings → Wi-Fi → tap your network → HTTP Proxy → Manual
   - Server: your Mac's IP
   - Port: 8080
3. For HTTPS challenges (N2): the app has a TLS vulnerability — investigate it
4. For N3/N6: certificate pinning is in play — you'll need to figure out how to get past it

---

## Challenges

### Storage (S1–S8)

| ID | Title | Difficulty | JB |
|----|-------|-----------|:--:|
| S1 | Plaintext Confessions | Basic | — |
| S2 | The Forgotten Plist | Basic | — |
| S3 | SQLite Diary | Basic | — |
| S4 | Keychain? Sure, But... | Medium | ✓ |
| S5 | CoreData Secrets | Medium | ✓ |
| S6 | Console.app Knows Everything | Medium | — |
| S7 | The Encrypted Lie | Hard | ✓ |
| S8 | Keychain Group Pivot | Hard | — |

### Network (N1–N7)

| ID | Title | Difficulty | JB |
|----|-------|-----------|:--:|
| N1 | Cleartext Credentials | Basic | — |
| N2 | Trust Everyone | Basic | — |
| N3 | Pinning? What Pinning? | Medium | ✓ |
| N4 | The WebSocket Whisper | Medium | — |
| N5 | JWT Weak Secret | Medium | — |
| N6 | Pinning Deeper | Hard | ✓ |
| N7 | OAuth State CSRF | Hard | — |

### WebView & JS Bridge (W1–W7)

| ID | Title | Difficulty | JB |
|----|-------|-----------|:--:|
| W1 | URL Scheme Hijack | Basic | — |
| W2 | postMessage Eavesdrop | Basic | — |
| W3 | Bridge Exposed | Medium | — |
| W4 | Universal Link Confusion | Medium | — |
| W5 | The Analytics SDK Pattern | Medium | — |
| W6 | localStorage Theft | Hard | ✓ |
| W7 | DeepLink Chain | Hard | — |

### Binary & Runtime (B1–B8)

| ID | Title | Difficulty | JB |
|----|-------|-----------|:--:|
| B1 | Strings Never Lie | Basic | — |
| B2 | The ObjC Method | Basic | ✓ |
| B3 | Debugger? No Thanks | Medium | ✓ |
| B4 | Jailbreak Blindfold | Medium | ✓ |
| B5 | Class Dump Treasure Hunt | Medium | ✓ |
| B6 | The Swizzle | Hard | ✓ |
| B7 | JB Detection: Advanced | Hard | ✓ |
| B8 | FairPlay Ghost | Hard | ✓ |

---

## Recommended Tools

| Tool | Used For | Install |
|------|---------|---------|
| [Frida](https://frida.re) | Runtime hooking, method swizzling | `pip install frida-tools` |
| [Objection](https://github.com/sensepost/objection) | iOS exploration, SSL bypass, keychain dump | `pip install objection` |
| [Burp Suite](https://portswigger.net/burp) | HTTP/HTTPS traffic interception | portswigger.net |
| [Ghidra](https://ghidra-sre.org) | Binary analysis, string search | ghidra-sre.org |
| [class-dump](https://github.com/nygard/class-dump) | ObjC header extraction | `brew install class-dump` |
| [wscat](https://github.com/websockets/wscat) | WebSocket client | `npm install -g wscat` |
| [jwt_tool](https://github.com/ticarpi/jwt_tool) | JWT analysis | GitHub |
| [hashcat](https://hashcat.net/hashcat/) | Password / token cracking | `brew install hashcat` |
| sqlite3 | Database inspection (S3, S5) | Pre-installed on macOS |
| idevicesyslog | Device console logs (S6) | `brew install libimobiledevice` |

---

## Project Structure

```
iOSCTF/
├── CTFApp/
│   ├── CTFAppApp.swift              App entry point (SwiftUI @main)
│   ├── CTFApp-Bridging-Header.h     ObjC ↔ Swift bridge
│   ├── CTFApp.entitlements          Shared keychain group (S8)
│   ├── Core/
│   │   ├── Challenge.swift          Data models
│   │   ├── ChallengeRegistry.swift  Loads challenges.json
│   │   ├── FlagValidator.swift      SHA256 local flag validation
│   │   ├── ProgressStore.swift      Score + hint tracking
│   │   └── JailbreakDetector.swift  Naive JB detection (B4 target)
│   ├── UI/
│   │   ├── HomeView.swift           Category grid + score
│   │   ├── ChallengeListView.swift  Challenge list per category
│   │   ├── ChallengeDetailView.swift Challenge detail + flag submit
│   │   └── ServerSetupView.swift    Server config + About page
│   ├── Resources/
│   │   ├── challenges.json          Challenge registry (30 challenges)
│   │   ├── Info.plist               URL schemes, ATS, file sharing
│   │   └── HTML/                    Bundled HTML for WebView challenges
│   └── VulnModules/
│       ├── Storage/                 S1–S8 vulnerable data setup
│       ├── Network/                 N1–N7 network layer vulns
│       ├── WebView/                 W1–W7 WebView + JS bridges
│       └── Binary/                  B1–B8 ObjC runtime targets
├── server/
│   ├── main.py                      FastAPI companion server
│   ├── requirements.txt             Python dependencies
│   └── static/                      HTML pages for WebView challenges
├── project.yml                      XcodeGen project spec
├── setup.sh                         One-command bootstrap
├── build_ipa.sh                     Build IPA for sideloading
└── README.md
```

---

## Flag Format

All flags follow: `IOSCTF{description_here}`

Flags are validated locally via SHA256 hash comparison — no server round-trip needed for submission.

---

## Server Endpoints

| Method | Path | Challenge | Protocol |
|--------|------|-----------|----------|
| POST | `/api/network/login` | N1 — Cleartext HTTP | HTTP :8000 |
| GET | `/api/network/insecure-data` | N2 — No TLS validation | HTTPS :8443 |
| GET | `/api/network/pinned-data` | N3 — Cert pinning | HTTPS :8443 |
| POST | `/api/ws/challenge` | N4 — Token exchange (HTTP) | HTTP :8000 |
| WS | `/api/ws/challenge` | N4 — Token replay (WebSocket) | WS :8000 |
| GET | `/api/auth/token` | N5 — Get JWT | HTTP :8000 |
| POST | `/api/auth/verify` | N5 — JWT verification | HTTP :8000 |
| GET | `/api/network/spki-pinned` | N6 — SPKI pinning | HTTPS :8443 |
| GET | `/api/oauth/authorize` | N7 — OAuth flow | HTTP :8000 |
| POST | `/api/oauth/token` | N7 — Code exchange | HTTP :8000 |
| GET | `/redirect?url=` | W4 — Open redirect | HTTP :8000 |
| GET | `/.well-known/apple-app-site-association` | W4 — AASA | HTTP :8000 |
| GET | `/static/*` | W3/W5/W6/W7 — WebView HTML | HTTP :8000 |
| GET | `/health` | Connectivity test | HTTP :8000 |

---

## Troubleshooting

**App is letterboxed / doesn't fill the screen:**
Delete the app from the device completely (long press → Remove App → Delete App), then rebuild from Xcode. iOS caches launch screen data from the first install.

**"Untrusted Developer" error on launch:**
Settings → General → VPN & Device Management → tap your Apple ID → Trust.

**XcodeGen not found:**
```bash
brew install xcodegen
```

**Server: "Address already in use":**
```bash
lsof -i :8000 | grep LISTEN    # find the PID
kill -9 <PID>
```

**Frida version mismatch:**
The `frida` Python package and `frida-server` on the device must be the same version:
```bash
frida --version                  # on Mac
ssh root@<device-ip> frida-server --version   # on device
pip install frida==<matching_version> frida-tools==<matching_version>
```

**N2/N3/N6 SSL errors in Burp:**
These challenges use HTTPS on port 8443. The companion server auto-generates a self-signed cert on first run. Make sure the server is running and shows "HTTPS listening on :8443" in the output.

**wscat not found (N4):**
```bash
npm install -g wscat
```

---

## Developers

**Mohammed Alsaeed** — Cybersecurity specialist who learns by breaking things. Focused on iOS security research, mobile penetration testing, and bug bounty hunting.

**Claude** (Anthropic) — AI assistant. Helped design challenge architecture, write vulnerable modules, and build the companion server.

---

## Inspired By

- [DVIA](https://github.com/prateek147/DVIA-v2) — Damn Vulnerable iOS App
- [iGoat](https://github.com/OWASP/iGoat-Swift) — OWASP iOS security training
- [OWASP MASTG](https://mas.owasp.org/MASTG/) — Mobile Application Security Testing Guide
- Common vulnerability patterns found across iOS applications in the wild

---

## Building the IPA

If you want to build the IPA yourself for distribution:

```bash
chmod +x build_ipa.sh
./build_ipa.sh
```

This creates `CTFApp.ipa` in the project root. Upload it to GitHub Releases:

```bash
# Tag a release
git tag -a v1.0 -m "Initial release"
git push origin v1.0

# Then upload CTFApp.ipa via GitHub web UI:
# Releases → Draft a new release → Attach CTFApp.ipa
```

> The build script requires Xcode on macOS. The resulting IPA can be sideloaded on any iPhone using the tools listed in the [Pre-built IPA](#pre-built-ipa-no-xcode-required) section.

---

## License

This project is for **educational and authorized security research purposes only**. Do not use the techniques demonstrated here against systems you do not own or have explicit permission to test.
