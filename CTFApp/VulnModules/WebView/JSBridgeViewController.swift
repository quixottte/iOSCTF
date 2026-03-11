//  JSBridgeViewController.swift
//  WebView challenge implementations — W2, W3, W5

import UIKit
import SwiftUI
import WebKit

// MARK: - W2: postMessage with discoverable handler name

/// VULN: Handler name 'secretGateway' is hardcoded in the bundled HTML
/// Challenge W2: extract the IPA, read the HTML, find the handler name, call it
class W2WebViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "secretGateway")
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "w2_challenge", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "secretGateway",
              let body = message.body as? [String: String],
              body["action"] == "getFlag"
        else { return }
        webView.evaluateJavaScript("receiveFlag('IOSCTF{W2_postmessage_leaked}')")
    }
}

// MARK: - W3: Exposed bridge — no origin check

/// VULN: 'flagBridge' handler accepts messages from any page, including MITM-injected JS
/// Challenge W3: MITM the page load via Burp, inject JS to call this handler
class W3WebViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!
    private let serverIP = UserDefaults.standard.string(forKey: "ctf_server_ip") ?? "localhost"

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "flagBridge")
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        let url = URL(string: "http://\(serverIP):8000/static/bridge_page.html")!
        webView.load(URLRequest(url: url))
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "flagBridge",
              let body = message.body as? [String: Any],
              let cmd = body["cmd"] as? String, cmd == "retrieve"
        else { return }

        let flag = "IOSCTF{W3_js_bridge_called_externally}"
        webView.evaluateJavaScript("alert('\(flag)')")
    }
}

// MARK: - W5: Analytics SDK bridge

/// VULN: An analytics SDK registers a JS bridge callable from any origin in the WebView.
/// The bridge can capture and exfiltrate localStorage content.
class W5WebViewController: UIViewController, WKScriptMessageHandler {

    var webView: WKWebView!
    private let serverIP = UserDefaults.standard.string(forKey: "ctf_server_ip") ?? "localhost"

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.processPool = SharedProcessPool.shared
        config.userContentController.add(self, name: "analyticsSDK")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        let sessionToken = "IOSCTF{W5_fullstory_pattern_exploited}"
        let seedScript = WKUserScript(
            source: "localStorage.setItem('session_token', '\(sessionToken)');",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(seedScript)

        let url = URL(string: "http://\(serverIP):8000/static/analytics_page.html")!
        webView.load(URLRequest(url: url))
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "analyticsSDK",
              let body = message.body as? [String: String],
              body["type"] == "capture"
        else { return }

        let target = body["target"] ?? ""
        if target == "localStorage" {
            webView.evaluateJavaScript("localStorage.getItem('session_token')") { result, _ in
                if let token = result as? String {
                    self.webView.evaluateJavaScript("alert('Captured: \(token)')")
                }
            }
        }
    }
}

// MARK: - Shared process pool for W6

class SharedProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - SwiftUI Wrappers

struct W2WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> W2WebViewController { W2WebViewController() }
    func updateUIViewController(_ vc: W2WebViewController, context: Context) {}
}

struct W3WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> W3WebViewController { W3WebViewController() }
    func updateUIViewController(_ vc: W3WebViewController, context: Context) {}
}

struct W5WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> W5WebViewController { W5WebViewController() }
    func updateUIViewController(_ vc: W5WebViewController, context: Context) {}
}
