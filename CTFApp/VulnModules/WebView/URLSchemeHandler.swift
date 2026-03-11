//  URLSchemeHandler.swift
//  URL scheme routing for W1 (ctfapp://reveal) and W7 (ctfapp://webload).

import UIKit
import SwiftUI
import CryptoKit
import WebKit

// MARK: - Shared flag store (observable by SwiftUI)

class URLSchemeFlagStore: ObservableObject {
    static let shared = URLSchemeFlagStore()
    @Published var revealedFlag: (challengeId: String, flag: String)? = nil
    private init() {}
}

// MARK: - URL Scheme Router

final class URLSchemeRouter {

    static let shared = URLSchemeRouter()
    private init() {}

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "ctfapp" else { return }
        switch url.host?.lowercased() {
        case "reveal":   handleReveal(url: url)
        case "webload":  handleWebLoad(url: url)
        default:
            print("[CTF] URLSchemeRouter: unknown host '\(url.host ?? "nil")' in \(url)")
        }
    }

    // MARK: - W1: ctfapp://reveal?key=<value>
    //
    // VULN: No validation of the calling app or origin.
    //       Any app or Safari page can trigger this URL scheme.
    //       The 'key' parameter is the only gate — and it's guessable.
    // Challenge W1: open Safari → ctfapp://reveal?key=admin

    private func handleReveal(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let key = components?.queryItems?.first(where: { $0.name == "key" })?.value

        // VULN: Simple string comparison — any app can call ctfapp://reveal?key=admin
        guard key == "admin" else {
            print("[CTF] W1: reveal called with wrong key: '\(key ?? "nil")'")
            return
        }

        let flag = "IOSCTF{W1_url_scheme_hijacked}"
        DispatchQueue.main.async {
            URLSchemeFlagStore.shared.revealedFlag = (challengeId: "W1", flag: flag)
        }
        print("[CTF] W1: Flag revealed via URL scheme")
    }

    // MARK: - W7: ctfapp://webload?url=<url>  (Stage 1 of DeepLink Chain)
    //
    // VULN: Whitelist check is incomplete — only validates host, not scheme or path.

    private func handleWebLoad(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let targetString = components?.queryItems?.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: targetString)
        else {
            print("[CTF] W7: webload called with no/invalid url param")
            return
        }

        // VULN: Only checks host — does not validate scheme or path
        let allowedHosts: Set<String> = ["localhost", "127.0.0.1"]
        guard let host = targetURL.host, allowedHosts.contains(host) else {
            print("[CTF] W7: rejected non-whitelisted host: \(targetURL.host ?? "nil")")
            return
        }

        NotificationCenter.default.post(
            name: .ctfLoadWebURL,
            object: nil,
            userInfo: ["url": targetURL]
        )
        print("[CTF] W7 Stage 1 passed — loading: \(targetURL)")
    }
}

// MARK: - W7 Stage 3: ChainBridge WKScriptMessageHandler

class ChainBridgeHandler: NSObject, WKScriptMessageHandler {

    // VULN: HMAC key sourced from UserDefaults (the S1 value — planted at startup).

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "chainBridge",
              let body = message.body as? [String: String],
              let providedHMAC = body["hmac"],
              let messageContent = body["message"]
        else { return }

        let hmacKey = UserDefaults.standard.string(forKey: "ctf_s1_flag") ?? ""
        guard !hmacKey.isEmpty else {
            print("[CTF] W7 Stage 3: HMAC key not found in UserDefaults — solve S1 first")
            return
        }

        if verifyHMAC(message: messageContent, key: hmacKey, provided: providedHMAC) {
            print("[CTF] W7 Stage 3 passed — chain complete")
            message.webView?.evaluateJavaScript(
                "receiveChainFlag('IOSCTF{W7_deeplink_chain_complete}')"
            )
        } else {
            print("[CTF] W7 Stage 3: HMAC mismatch — incorrect key or message")
        }
    }

    private func verifyHMAC(message: String, key: String, provided: String) -> Bool {
        let keyData = SymmetricKey(data: Data(key.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: keyData)
        let expected = Data(mac).map { String(format: "%02x", $0) }.joined()
        return expected == provided
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let ctfFlagRevealed = Notification.Name("com.iosctf.flagRevealed")
    static let ctfLoadWebURL   = Notification.Name("com.iosctf.loadWebURL")
}
