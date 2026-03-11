//  ServerSetupView.swift — Guide for companion server setup + connectivity check

import SwiftUI

struct ServerSetupView: View {
    @AppStorage("ctf_server_ip") private var serverIP = ""
    @State private var pingResult: String = ""
    @State private var isPinging = false

    var serverURL: String { "http://\(serverIP):8000" }

    var body: some View {
        Form {
            Section(header: Text("Companion Server")) {
                HStack {
                    Text("Mac IP:")
                    TextField("192.168.1.x", text: $serverIP)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Text("HTTP: 8000 | HTTPS: 8443")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section(header: Text("Quick Start")) {
                VStack(alignment: .leading, spacing: 8) {
                    CodeBlock("cd iOSCTF/server")
                    CodeBlock("pip install -r requirements.txt")
                    CodeBlock("python main.py")
                }
            }

            Section(header: Text("Connectivity")) {
                Button(action: pingServer) {
                    HStack {
                        if isPinging {
                            ProgressView().frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(serverIP.isEmpty || isPinging)

                if !pingResult.isEmpty {
                    Text(pingResult)
                        .font(.callout)
                        .foregroundColor(pingResult.contains("✅") ? .green : .red)
                }
            }

            Section(header: Text("Server Challenges")) {
                ForEach(CTFChallengeRegistry.shared.serverChallenges(), id: \.id) { c in
                    HStack {
                        Text(c.id).font(.caption.monospaced()).foregroundColor(.secondary)
                        Text(c.title)
                        Spacer()
                        if let ep = c.serverEndpoint {
                            Text(ep).font(.caption.monospaced()).foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Companion Server")
    }

    private func pingServer() {
        guard let url = URL(string: "\(serverURL)/health") else { return }
        isPinging = true
        pingResult = ""
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isPinging = false
                if let error = error {
                    pingResult = "❌ \(error.localizedDescription)"
                } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    pingResult = "✅ Server reachable at \(serverURL)"
                } else {
                    pingResult = "❌ Unexpected response"
                }
            }
        }.resume()
    }
}

struct CodeBlock: View {
    let code: String
    init(_ code: String) { self.code = code }
    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(6)
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // App description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iOSCTF")
                            .font(.largeTitle.bold())
                        Text("A deliberately vulnerable iOS application for learning mobile penetration testing, security research, and iOS internals.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Warning
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        Text("This app is intentionally insecure. Never install on a device containing sensitive personal data.")
                            .foregroundColor(.orange)
                            .font(.callout)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)

                    Divider()

                    // Developers
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Developers", systemImage: "person.2.fill")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mohammed Alsaeed")
                                .font(.body.bold())
                            Text("Cybersecurity specialist passionate about understanding how systems work — by taking them apart. Focused on iOS security research, mobile penetration testing, and bug bounty hunting.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Claude")
                                .font(.body.bold())
                            Text("AI assistant by Anthropic. Helped design challenge architecture, write vulnerable modules, and build the companion server.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }

                    Divider()

                    // Challenge info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Challenge Details", systemImage: "flag.fill")
                            .font(.headline)

                        InfoRow(label: "Flag format", value: "IOSCTF{...}")
                        InfoRow(label: "Validation", value: "Local SHA256 — no server needed")
                        InfoRow(label: "Categories", value: "Storage, Network, WebView, Binary")
                        InfoRow(label: "Total", value: "30 challenges across 4 pillars")
                    }

                    Divider()

                    // Tools
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Recommended Tools", systemImage: "wrench.and.screwdriver")
                            .font(.headline)

                        Text("Frida, Objection, Burp Suite, Ghidra, class-dump, sqlite3, keychain-dumper, idevicesyslog")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Inspiration
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Inspired By", systemImage: "sparkles")
                            .font(.headline)

                        Text("DVIA, iGoat, OWASP MASTG, and common vulnerability patterns found across iOS applications in the wild.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Text("v1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.callout, design: .monospaced))
        }
    }
}
