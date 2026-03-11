//  ChallengeRegistry.swift
//  iOSCTF — Loads and queries challenges from the JSON bundle resource

import Foundation

final class CTFChallengeRegistry {

    static let shared = CTFChallengeRegistry()
    private(set) var challenges: [Challenge] = []

    private init() { load() }

    // MARK: - Load

    private func load() {
        guard let url = Bundle.main.url(forResource: "challenges", withExtension: "json") else {
            fatalError("[CTF] challenges.json not found in bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            let registry = try JSONDecoder().decode(ChallengeRegistry.self, from: data)
            challenges = registry.challenges
            print("[CTF] Loaded \(challenges.count) challenges (registry v\(registry.version))")
        } catch {
            fatalError("[CTF] Failed to parse challenges.json: \(error)")
        }
    }

    // MARK: - Queries

    func challenges(for category: ChallengeCategory) -> [Challenge] {
        challenges
            .filter { $0.category == category }
            .sorted { $0.difficulty < $1.difficulty }
    }

    func challenge(id: String) -> Challenge? {
        challenges.first { $0.id == id }
    }

    func challenges(difficulty: Difficulty) -> [Challenge] {
        challenges.filter { $0.difficulty == difficulty }
    }

    func serverChallenges() -> [Challenge] {
        challenges.filter { $0.serverChallenge }
    }

    func jailbreakRequired() -> [Challenge] {
        challenges.filter { $0.requiresJailbreak }
    }

    // Returns challenges playable on non-jailbroken devices
    func accessibleChallenges() -> [Challenge] {
        challenges.filter { !$0.requiresJailbreak }
    }

    var totalPoints: Int {
        challenges.reduce(0) { $0 + $1.difficulty.points }
    }
}
