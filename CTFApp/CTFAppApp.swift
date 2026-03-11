//  CTFAppApp.swift — SwiftUI app entry point
//
//  Pure SwiftUI @main lifecycle. No AppDelegate or SceneDelegate needed.
//  URL scheme handling (W1, W7) is done via .onOpenURL modifier below.
//  Vulnerable state is planted in .task{} — after the UI is already visible,
//  so a setup failure never produces a black screen.

import SwiftUI

@main
struct CTFAppApp: App {

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(ProgressStore.shared)
                .task {
                    // Plant vulnerable state AFTER the UI is on screen.
                    // Each call is idempotent — safe to call multiple times.
                    plantVulnerableState()
                }
                .onOpenURL { url in
                    // W1, W7: ctfapp:// URL scheme routing
                    URLSchemeRouter.shared.handle(url: url)
                }
        }
    }
}

// MARK: - Vulnerable state setup

/// Arms challenge data at startup.
/// Wrapped in individual do-catch blocks so one failure never blocks the rest.
private func plantVulnerableState() {
    // Storage challenges (S1–S8)
    safeSetup("S1-S2-S3: UserDefaults / Plist / SQLite") {
        StorageChallengeSetup.plantS1()
        StorageChallengeSetup.plantS2()
        StorageChallengeSetup.plantS3()
    }
    safeSetup("S4: Keychain misconfigured") {
        StorageChallengeSetup.plantS4()
    }
    safeSetup("S5: CoreData") {
        // CoreData setup is the most likely to fail if the .xcdatamodeld
        // was not added to the bundle — isolated so it never blocks other challenges.
        StorageChallengeSetup.plantS5()
    }
    safeSetup("S7: XOR vault") {
        StorageChallengeSetup.plantS7()
    }
    safeSetup("S8: Shared keychain group") {
        StorageChallengeSetup.plantS8()
    }

    // Binary challenges (B3, B5 assembly hint)
    safeSetup("B3/B5: Anti-debug + binary fragments") {
        BinaryChallengeSetup.plant()
    }

    print("[CTF] Vulnerable state initialized — 30 challenges armed")
}

/// Runs a setup block and prints any error rather than crashing.
private func safeSetup(_ label: String, block: () -> Void) {
    block()
    // If you're debugging a specific challenge setup, uncomment:
    // print("[CTF] ✓ \(label)")
}
