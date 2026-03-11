//  HomeView.swift — Root view: category grid + score header

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var progress: ProgressStore
    @State private var showingAbout = false

    private let registry = CTFChallengeRegistry.shared
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    scoreHeader
                    categoryGrid
                    serverStatusBanner
                }
                .padding()
            }
            .navigationTitle("iOS CTF")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAbout = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(spacing: 16) {
            ScoreStat(label: "Score", value: "\(progress.totalScore)")
            Divider().frame(height: 40)
            ScoreStat(label: "Solved", value: "\(progress.solvedCount) / \(registry.challenges.count)")
            Divider().frame(height: 40)
            ScoreStat(label: "Max", value: "\(registry.totalPoints)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(ChallengeCategory.allCases, id: \.self) { category in
                NavigationLink(destination: ChallengeListView(category: category)) {
                    CategoryCard(
                        category: category,
                        total: registry.challenges(for: category).count,
                        solved: solvedCount(for: category)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Server status

    private var serverStatusBanner: some View {
        HStack {
            Image(systemName: "server.rack")
            Text("Companion server required for \(registry.serverChallenges().count) challenges")
                .font(.caption)
            Spacer()
            NavigationLink("Setup →", destination: ServerSetupView())
                .font(.caption.bold())
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private func solvedCount(for category: ChallengeCategory) -> Int {
        registry.challenges(for: category).filter { progress.isSolved(challengeId: $0.id) }.count
    }
}

// MARK: - Supporting Views

struct ScoreStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryCard: View {
    let category: ChallengeCategory
    let total: Int
    let solved: Int

    private var progress: Double {
        total > 0 ? Double(solved) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.emoji).font(.title)
                Spacer()
                Text("\(solved)/\(total)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            Text(category.displayName)
                .font(.headline)
                .multilineTextAlignment(.leading)
            ProgressView(value: progress)
                .tint(progress == 1.0 ? .green : .blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
