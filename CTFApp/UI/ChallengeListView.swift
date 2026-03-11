//  ChallengeListView.swift — List of challenges for a given category

import SwiftUI

struct ChallengeListView: View {
    let category: ChallengeCategory
    @EnvironmentObject var progress: ProgressStore

    private var challenges: [Challenge] {
        CTFChallengeRegistry.shared.challenges(for: category)
    }

    var body: some View {
        List {
            ForEach([Difficulty.basic, .medium, .hard], id: \.self) { diff in
                let group = challenges.filter { $0.difficulty == diff }
                if !group.isEmpty {
                    Section(header: difficultyHeader(diff)) {
                        ForEach(group) { challenge in
                            NavigationLink(destination: ChallengeDetailView(challenge: challenge)) {
                                ChallengeRow(challenge: challenge, isSolved: progress.isSolved(challengeId: challenge.id))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(category.emoji) \(category.displayName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func difficultyHeader(_ diff: Difficulty) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: diff.colorHex))
                .frame(width: 8, height: 8)
            Text(diff.displayName.uppercased())
                .font(.caption.bold())
            Spacer()
            Text("\(diff.points) pts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ChallengeRow: View {
    let challenge: Challenge
    let isSolved: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: isSolved ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSolved ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(challenge.id)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    if challenge.requiresJailbreak {
                        Image(systemName: "lock.open.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if challenge.serverChallenge {
                        Image(systemName: "server.rack")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                Text(challenge.title)
                    .font(.body.weight(isSolved ? .regular : .medium))

                // Tag chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(challenge.tags.prefix(3), id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
            }

            Spacer()

            Text("\(challenge.difficulty.points)pt")
                .font(.caption.bold())
                .foregroundColor(Color(hex: challenge.difficulty.colorHex))
        }
        .padding(.vertical, 4)
        .opacity(isSolved ? 0.6 : 1.0)
    }
}

struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(4)
            .foregroundColor(.secondary)
    }
}

// MARK: - Color+Hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}
