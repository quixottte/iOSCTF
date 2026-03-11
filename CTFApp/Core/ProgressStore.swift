//  ProgressStore.swift
//  iOSCTF — Persists solved challenges, hints used, and score

import Foundation
import Combine

final class ProgressStore: ObservableObject {

    static let shared = ProgressStore()
    private let storageKey = "ctf_progress_v1"

    @Published private(set) var progress: [String: ChallengeProgress] = [:]

    private init() { load() }

    // MARK: - Public API

    func isSolved(challengeId: String) -> Bool {
        progress[challengeId]?.solved ?? false
    }

    func hintsUsed(challengeId: String) -> Int {
        progress[challengeId]?.hintsUsed ?? 0
    }

    func markSolved(challengeId: String, difficulty: Difficulty) {
        var entry = progress[challengeId] ?? ChallengeProgress(
            challengeId: challengeId, solved: false, hintsUsed: 0, solvedAt: nil, pointsEarned: 0
        )
        guard !entry.solved else { return }

        let hintPenalty = (entry.hintsUsed * 25)   // -25 pts per hint used
        entry.solved     = true
        entry.solvedAt   = Date()
        entry.pointsEarned = max(0, difficulty.points - hintPenalty)
        progress[challengeId] = entry
        save()
    }

    func recordHintUsed(challengeId: String) {
        var entry = progress[challengeId] ?? ChallengeProgress(
            challengeId: challengeId, solved: false, hintsUsed: 0, solvedAt: nil, pointsEarned: 0
        )
        entry.hintsUsed += 1
        progress[challengeId] = entry
        save()
    }

    var totalScore: Int {
        progress.values.reduce(0) { $0 + $1.pointsEarned }
    }

    var solvedCount: Int {
        progress.values.filter { $0.solved }.count
    }

    func solvedChallenges() -> [ChallengeProgress] {
        progress.values.filter { $0.solved }.sorted { ($0.solvedAt ?? .distantPast) < ($1.solvedAt ?? .distantPast) }
    }

    // MARK: - Dev helpers

    #if DEBUG
    func resetAll() {
        progress = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    #endif

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        // NOTE: Intentionally using UserDefaults — this IS one of the challenge's storage vulns (S1)
        // Progress data is non-sensitive; flag data is never stored.
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ChallengeProgress].self, from: data)
        else { return }
        progress = decoded
    }
}
