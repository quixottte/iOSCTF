//  Challenge.swift
//  iOSCTF — Data models for challenge registry

import Foundation

// MARK: - Enums

enum ChallengeCategory: String, Codable, CaseIterable {
    case storage = "storage"
    case network = "network"
    case webview = "webview"
    case binary  = "binary"

    var displayName: String {
        switch self {
        case .storage: return "Storage"
        case .network: return "Network"
        case .webview: return "WebView & JS Bridge"
        case .binary:  return "Binary & Runtime"
        }
    }

    var emoji: String {
        switch self {
        case .storage: return "🗄️"
        case .network: return "🌐"
        case .webview: return "🌍"
        case .binary:  return "⚙️"
        }
    }
}

enum Difficulty: String, Codable, Comparable {
    case basic  = "basic"
    case medium = "medium"
    case hard   = "hard"

    var displayName: String { rawValue.capitalized }

    var points: Int {
        switch self {
        case .basic:  return 100
        case .medium: return 250
        case .hard:   return 500
        }
    }

    var colorHex: String {
        switch self {
        case .basic:  return "#34C759"   // green
        case .medium: return "#FF9500"   // orange
        case .hard:   return "#FF3B30"   // red
        }
    }

    // Comparable conformance for sorting
    private var sortOrder: Int {
        switch self { case .basic: return 0; case .medium: return 1; case .hard: return 2 }
    }
    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.sortOrder < rhs.sortOrder }
}

// MARK: - Challenge

struct Challenge: Codable, Identifiable {
    let id: String
    let title: String
    let category: ChallengeCategory
    let difficulty: Difficulty
    let description: String
    let objective: String
    let hints: [String]
    let flagHash: String          // SHA256 of IOSCTF{...}
    let requiresJailbreak: Bool
    let serverChallenge: Bool
    let serverEndpoint: String?
    let tags: [String]
    let tools: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, category, difficulty, description, objective
        case hints, tags, tools
        case flagHash        = "flag_hash"
        case requiresJailbreak = "requires_jailbreak"
        case serverChallenge   = "server_challenge"
        case serverEndpoint    = "server_endpoint"
    }
}

// MARK: - Registry envelope

struct ChallengeRegistry: Codable {
    let version: String
    let challenges: [Challenge]
}

// MARK: - Progress entry (stored locally)

struct ChallengeProgress: Codable {
    let challengeId: String
    var solved: Bool
    var hintsUsed: Int
    var solvedAt: Date?
    var pointsEarned: Int
}
