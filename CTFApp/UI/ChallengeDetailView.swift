//  ChallengeDetailView.swift — Full challenge description, hints, flag submit

import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    @EnvironmentObject var progress: ProgressStore
    @ObservedObject private var flagStore = URLSchemeFlagStore.shared

    @State private var flagInput = ""
    @State private var submissionResult: SubmissionState = .idle
    @State private var revealedHints: Set<Int> = []
    @State private var showingConfetti = false
    @State private var networkStatus: String = ""
    @State private var isLoading = false
    @State private var showWebView = false
    @State private var urlSchemeAlert = false

    enum SubmissionState {
        case idle, correct, incorrect, invalidFormat, alreadySolved
        var message: String {
            switch self {
            case .idle:          return ""
            case .correct:       return "✅ Correct! Flag accepted."
            case .incorrect:     return "❌ Incorrect flag. Keep trying."
            case .invalidFormat: return "⚠️ Flags must start with IOSCTF{"
            case .alreadySolved: return "✅ Already solved."
            }
        }
        var color: Color {
            switch self {
            case .correct, .alreadySolved: return .green
            case .incorrect:               return .red
            case .invalidFormat:           return .orange
            case .idle:                    return .clear
            }
        }
    }

    var isSolved: Bool { progress.isSolved(challengeId: challenge.id) }
    var isNetworkChallenge: Bool { challenge.id.hasPrefix("N") }
    var isWebViewChallenge: Bool { ["W2", "W3", "W5"].contains(challenge.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                objectiveSection
                descriptionSection

                if isNetworkChallenge {
                    networkActionSection
                }

                if isWebViewChallenge {
                    webViewSection
                }

                if challenge.id == "B8" {
                    b8TriggerSection
                }

                toolsSection
                hintsSection
                flagSection
            }
            .padding()
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { triggerChallengeSetup() }
        .onChange(of: flagStore.revealedFlag?.challengeId) { newVal in
            if newVal == challenge.id, let flag = flagStore.revealedFlag?.flag {
                flagInput = flag
                urlSchemeAlert = true
            }
        }
        .alert("URL Scheme Flag", isPresented: $urlSchemeAlert) {
            Button("OK") {}
        } message: {
            Text(flagStore.revealedFlag?.flag ?? "")
        }
        .sheet(isPresented: $showWebView) {
            webViewSheet
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    DifficultyBadge(difficulty: challenge.difficulty)
                    Text(challenge.id).font(.caption.monospaced()).foregroundColor(.secondary)
                    if challenge.requiresJailbreak {
                        Label("JB Required", systemImage: "lock.open")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
                if challenge.serverChallenge, let endpoint = challenge.serverEndpoint {
                    HStack {
                        Image(systemName: "server.rack").foregroundColor(.blue)
                        Text(endpoint).font(.caption.monospaced()).foregroundColor(.blue)
                    }
                }
            }
            Spacer()
            if isSolved {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
    }

    private var objectiveSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Objective", systemImage: "target")
                .font(.headline)
            Text(challenge.objective)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Background", systemImage: "doc.text")
                .font(.headline)
            Text(challenge.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Network Action

    private var networkActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Network Action", systemImage: "network")
                .font(.headline)

            Text("Server: \(CTFServer.httpBase)")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Button(action: fireNetworkChallenge) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(networkButtonLabel)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)

            if !networkStatus.isEmpty {
                Text(networkStatus)
                    .font(.callout.monospaced())
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }

    private var networkButtonLabel: String {
        switch challenge.id {
        case "N1": return "Send Login (HTTP)"
        case "N2": return "Send Insecure Request (HTTPS)"
        case "N3": return "Send Pinned Request (HTTPS)"
        case "N4": return "Send WS Token (HTTP)"
        case "N5": return "Fetch JWT Token"
        case "N6": return "Send SPKI-Pinned Request"
        case "N7": return "Start OAuth Flow"
        default:   return "Fire Request"
        }
    }

    // MARK: - WebView Section (W2, W3, W5)

    private var webViewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("WebView", systemImage: "globe")
                .font(.headline)

            Button(action: { showWebView = true }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Open Challenge WebView")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var webViewSheet: some View {
        NavigationView {
            Group {
                switch challenge.id {
                case "W2": W2WebView()
                case "W3": W3WebView()
                case "W5": W5WebView()
                default: Text("No WebView for this challenge")
                }
            }
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showWebView = false }
                }
            }
        }
    }

    // MARK: - B8 Trigger

    private var b8TriggerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Memory Window", systemImage: "memorychip")
                .font(.headline)

            Text("Triggers AES decryption → flag in memory for ~2 seconds → zeroed.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: {
                CTFMemoryVault.triggerAndScan()
                networkStatus = "Memory window OPEN for 2 seconds — scan now!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    networkStatus = "Memory window CLOSED. Flag zeroed."
                }
            }) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Trigger Memory Decrypt")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !networkStatus.isEmpty {
                Text(networkStatus)
                    .font(.callout.monospaced())
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Standard sections

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Suggested Tools", systemImage: "wrench.and.screwdriver")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(challenge.tools, id: \.self) { tool in
                        Text(tool)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var hintsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Hints", systemImage: "lightbulb")
                    .font(.headline)
                Spacer()
                Text("-25 pts each")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            ForEach(Array(challenge.hints.enumerated()), id: \.offset) { idx, hint in
                HintRow(
                    index: idx + 1,
                    hint: hint,
                    isRevealed: revealedHints.contains(idx)
                ) {
                    revealHint(idx)
                }
            }
        }
    }

    private var flagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Submit Flag", systemImage: "flag.fill")
                .font(.headline)

            HStack {
                TextField("IOSCTF{...}", text: $flagInput)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                Button(action: submitFlag) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(flagInput.isEmpty)
            }

            if submissionResult != .idle {
                Text(submissionResult.message)
                    .foregroundColor(submissionResult.color)
                    .font(.callout)
            }
        }
    }

    // MARK: - Actions

    private func fireNetworkChallenge() {
        isLoading = true
        networkStatus = "Sending..."

        switch challenge.id {
        case "N1":
            NetworkChallengeManager.n1Login { _ in
                isLoading = false
                networkStatus = "📡 Request sent — intercept it in Burp!"
            }
        case "N2":
            NetworkChallengeManager.n2InsecureRequest { _ in
                isLoading = false
                networkStatus = "📡 Request sent — intercept it in Burp!"
            }
        case "N3":
            NetworkChallengeManager.n3PinnedRequest { flag in
                isLoading = false
                if let flag = flag {
                    networkStatus = "✅ Response: \(flag)"
                } else {
                    networkStatus = "🔒 Pinning rejected the server cert — bypass it!"
                }
            }
        case "N4":
            NetworkChallengeManager.n4SendWSToken { hint in
                isLoading = false
                if let hint = hint {
                    networkStatus = "📡 Token sent — visible in Burp HTTP history!\n\(hint)"
                } else {
                    networkStatus = "📡 Token sent — check Burp HTTP history for the Authorization header!"
                }
            }
        case "N5":
            NetworkChallengeManager.n5FetchToken { token in
                isLoading = false
                if let token = token {
                    networkStatus = "🔑 JWT received: \(token.prefix(50))..."
                } else {
                    networkStatus = "📡 Request sent — intercept the token in Burp!"
                }
            }
        case "N6":
            NetworkChallengeManager.n6SPKIPinnedRequest { flag in
                isLoading = false
                if let flag = flag {
                    networkStatus = "✅ Response: \(flag)"
                } else {
                    networkStatus = "🔒 SPKI pin rejected — hook SecTrustEvaluateWithError!"
                }
            }
        case "N7":
            NetworkChallengeManager.n7StartOAuth { hint in
                isLoading = false
                if let hint = hint {
                    networkStatus = "📡 OAuth flow started — check Burp!\n\(hint)"
                } else {
                    networkStatus = "📡 OAuth request sent — intercept and modify the state parameter in Burp!"
                }
            }
        default:
            isLoading = false
            networkStatus = "No network action for this challenge."
        }
    }

    private func submitFlag() {
        let result = FlagValidator.shared.validate(input: flagInput, challenge: challenge)
        submissionResult = SubmissionState(from: result)

        if case .correct = result {
            progress.markSolved(challengeId: challenge.id, difficulty: challenge.difficulty)
            showingConfetti = true
        }
    }

    private func revealHint(_ index: Int) {
        guard !revealedHints.contains(index) else { return }
        revealedHints.insert(index)
        progress.recordHintUsed(challengeId: challenge.id)
    }

    /// Trigger any side-effects needed for the challenge
    private func triggerChallengeSetup() {
        switch challenge.id {
        case "S6":
            NSLog("[CTF] S6 flag triggered: IOSCTF{S6_nslog_leaks_to_console}")
        case "S1":
            StorageChallengeSetup.plantS1()
        case "S5":
            CoreDataManager.shared.plantS5Flag()
        default:
            break
        }
    }
}

// MARK: - Supporting views

struct DifficultyBadge: View {
    let difficulty: Difficulty
    var body: some View {
        Text(difficulty.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: difficulty.colorHex).opacity(0.15))
            .foregroundColor(Color(hex: difficulty.colorHex))
            .cornerRadius(5)
    }
}

struct HintRow: View {
    let index: Int
    let hint: String
    let isRevealed: Bool
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Hint \(index)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if !isRevealed {
                    Button("Reveal (-25pts)", action: onReveal)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if isRevealed {
                Text(hint)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .transition(.opacity)
            } else {
                Text("██████████████████████")
                    .font(.callout)
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

extension ChallengeDetailView.SubmissionState {
    init(from result: FlagValidationResult) {
        switch result {
        case .correct:       self = .correct
        case .incorrect:     self = .incorrect
        case .invalidFormat: self = .invalidFormat
        case .alreadySolved: self = .alreadySolved
        }
    }
}
