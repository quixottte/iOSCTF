//  FlagValidator.swift
//  iOSCTF — Local SHA256-based flag validation (no server round-trip needed)

import Foundation
import CryptoKit

enum FlagValidationResult {
    case correct
    case incorrect
    case invalidFormat      // doesn't start with IOSCTF{
    case alreadySolved
}

final class FlagValidator {

    static let shared = FlagValidator()
    private let flagPrefix = "IOSCTF{"
    private let flagSuffix = "}"

    private init() {}

    // MARK: - Public

    func validate(input: String, challenge: Challenge) -> FlagValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix(flagPrefix), trimmed.hasSuffix(flagSuffix) else {
            return .invalidFormat
        }

        if ProgressStore.shared.isSolved(challengeId: challenge.id) {
            return .alreadySolved
        }

        let computed = sha256(trimmed)
        return computed == challenge.flagHash ? .correct : .incorrect
    }

    // MARK: - Utility

    /// Returns SHA256 hex string of a flag — use this in scripts/flag_gen.py to generate hashes
    func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // Convenience: validate by challenge ID only
    func validate(input: String, challengeId: String) -> FlagValidationResult {
        guard let challenge = CTFChallengeRegistry.shared.challenge(id: challengeId) else {
            return .incorrect
        }
        return validate(input: input, challenge: challenge)
    }
}
