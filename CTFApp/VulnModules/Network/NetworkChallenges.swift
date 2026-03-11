//  NetworkChallenges.swift
//  Network layer vulnerabilities — N1 through N7

import Foundation

// MARK: - Server URL helpers

enum CTFServer {
    static var ip: String {
        UserDefaults.standard.string(forKey: "ctf_server_ip") ?? "localhost"
    }
    static var httpBase:  String { "http://\(ip):8000" }
    static var httpsBase: String { "https://\(ip):8443" }
    static var wsBase:    String { "ws://\(ip):8000" }
}

// MARK: - NetworkChallengeManager

@objc class NetworkChallengeManager: NSObject {

    // MARK: - N1: Cleartext HTTP POST

    static func n1Login(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(CTFServer.httpBase)/api/network/login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "username": "ctfuser",
            "password": "supersecret123"
        ])
        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async { completion(nil) }
        }.resume()
    }

    // MARK: - N2: Disabled TLS validation

    static func n2InsecureRequest(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(CTFServer.httpsBase)/api/network/insecure-data") else { return }
        let session = URLSession(configuration: .default,
                                 delegate: TrustAllDelegate(),
                                 delegateQueue: nil)
        session.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.async { completion(nil) }
        }.resume()
    }

    // MARK: - N3: Certificate pinning

    static func n3PinnedRequest(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(CTFServer.httpsBase)/api/network/pinned-data") else { return }
        let pinnedSPKIHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        let session = URLSession(configuration: .default,
                                 delegate: PinnedCertDelegate(expectedHash: pinnedSPKIHash),
                                 delegateQueue: nil)
        session.dataTask(with: url) { data, _, _ in
            let resp = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            DispatchQueue.main.async { completion(resp?["flag"]) }
        }.resume()
    }

    // MARK: - N4: WebSocket with replayable token
    //
    // VULN: Token = base64(username:timestamp) — no HMAC, no nonce, replayable within 300s.
    // The app sends the token via HTTP POST (interceptable in Burp).
    // Challenge: decode the token from Burp, replay it via wscat directly to the server.

    static func n4SendWSToken(completion: @escaping (String?) -> Void) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let raw = "ctfuser:\(timestamp)"
        let token = Data(raw.utf8).base64EncodedString()   // VULN: unsigned, predictable

        // Send token via regular HTTP POST — this goes through Burp proxy
        guard let url = URL(string: "\(CTFServer.httpBase)/api/ws/challenge") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")  // VULN: token in header
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,       // VULN: same token in body
            "action": "authenticate"
        ])
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let resp = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            DispatchQueue.main.async { completion(resp?["hint"]) }
        }.resume()
    }

    // MARK: - N5: Fetch JWT

    static func n5FetchToken(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(CTFServer.httpBase)/api/auth/token") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let resp = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            DispatchQueue.main.async { completion(resp?["token"]) }
        }.resume()
    }

    // MARK: - N6: SPKI Pinning (deeper — C-level hook required)

    static func n6SPKIPinnedRequest(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(CTFServer.httpsBase)/api/network/spki-pinned") else { return }
        let session = URLSession(configuration: .default,
                                 delegate: SPKIPinDelegate(),
                                 delegateQueue: nil)
        session.dataTask(with: url) { data, _, _ in
            let resp = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            DispatchQueue.main.async { completion(resp?["flag"]) }
        }.resume()
    }

    // MARK: - N7: OAuth CSRF (state parameter not validated)
    //
    // VULN: App starts OAuth flow. State parameter is present but server never validates it.
    // Challenge: intercept in Burp, change state to contain "admin", get admin code.
    // Then POST to /api/oauth/token with the admin code.

    static func n7StartOAuth(completion: @escaping (String?) -> Void) {
        let state = "user_\(Int.random(in: 10000...99999))"  // VULN: predictable, not validated on callback
        let clientId = "ctfapp"
        let redirectURI = "ctfapp://oauth/callback"

        var components = URLComponents(string: "\(CTFServer.httpBase)/api/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),       // VULN: change this to contain "admin"
        ]

        guard let url = components.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let resp = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            DispatchQueue.main.async { completion(resp?["hint"]) }
        }.resume()
    }
}

// MARK: - TrustAllDelegate — N2

class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - PinnedCertDelegate — N3

class PinnedCertDelegate: NSObject, URLSessionDelegate {
    private let expectedHash: String
    init(expectedHash: String) { self.expectedHash = expectedHash }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        guard let cert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let certData = SecCertificateCopyData(cert) as Data
        let actualHash = certData.base64EncodedString()
        if actualHash == expectedHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - SPKIPinDelegate — N6 (harder pinning)

/// VULN: SPKI public-key pinning. Objection's generic bypass may not work.
/// Must hook SecTrustEvaluateWithError at the C level with Frida Interceptor.
class SPKIPinDelegate: NSObject, URLSessionDelegate {
    // Hardcoded SPKI hash — will never match Burp's cert
    private let pinnedSPKIHash = "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Evaluate trust first
        var error: CFError?
        let isTrusted = SecTrustEvaluateWithError(serverTrust, &error)

        guard isTrusted,
              let cert = SecTrustGetCertificateAtIndex(serverTrust, 0)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Extract SPKI and compare hash
        let certData = SecCertificateCopyData(cert) as Data
        let spkiHash = "sha256/" + certData.base64EncodedString()

        if spkiHash == pinnedSPKIHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            print("[CTF] N6: SPKI pin mismatch — hook SecTrustEvaluateWithError to bypass")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
