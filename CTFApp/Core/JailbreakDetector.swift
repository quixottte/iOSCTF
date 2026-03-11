//  JailbreakDetector.swift
//  iOSCTF — Naive jailbreak detection (intentionally bypassable — see B4, B7)
//
//  This is DELIBERATELY weak. It is the target of challenges B4 and B7.
//  Challenge B4: bypass this naive version.
//  Challenge B7: a harder multi-layer version is in VulnModules/Binary/

import Foundation
import UIKit

@objc class CTFJailbreakDetector: NSObject {

    @objc static let shared = CTFJailbreakDetector()

    // MARK: - Detection (naive — challenge B4 target)

    /// Returns true if device appears to be jailbroken.
    /// Intentionally uses only file-system checks — trivially bypassable.
    @objc func isJailbroken() -> Bool {
        return checkCommonJailbreakFiles()
            || checkSandboxViolation()
            || checkDynamicLibraries()
    }

    // MARK: - B4 Flag Reveal
    //
    // VULN: When isJailbroken() returns false on a jailbroken device,
    //       it means detection was bypassed — reveal the flag.
    // Hook isJailbroken to return false, then call revealFlagIfBypassed().
    // Or: hook checkCommonJailbreakFiles / checkSandboxViolation / checkDynamicLibraries
    //     individually to all return false.

    @objc func revealFlagIfBypassed() -> String {
        if isJailbroken() {
            return "ACCESS_DENIED: Jailbreak detected. Bypass detection first."
        }
        return "IOSCTF{B4_jailbreak_detection_blinded}"
    }

    // MARK: - Individual checks (each individually hookable)

    /// Check 1: Existence of common jailbreak artifacts
    @objc func checkCommonJailbreakFiles() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/usr/bin/ssh",
            "/usr/sbin/sshd",
            "/bin/bash",
            "/etc/apt",
            "/.installed_unc0ver",
            "/.bootstrapped_electra",
            "/var/jb"                      // Dopamine / Fugu15
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }

    /// Check 2: Write outside sandbox
    @objc func checkSandboxViolation() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true   // wrote outside sandbox — JB
        } catch {
            return false  // expected on stock
        }
    }

    /// Check 3: Injected dynamic libraries (Substrate / Dopamine hooks)
    @objc func checkDynamicLibraries() -> Bool {
        let suspicious = ["SubstrateLoader", "CydiaSubstrate", "cynject", "libhooker", "Dopamine"]
        for i in 0..<_dyld_image_count() {
            if let name = _dyld_get_image_name(i) {
                let str = String(cString: name)
                for keyword in suspicious {
                    if str.lowercased().contains(keyword.lowercased()) {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - UI helpers

    var statusDescription: String {
        isJailbroken() ? "Jailbroken device detected" : "Device appears to be stock"
    }

    var isJailbreakRequired: Bool {
        return !isJailbroken()
    }
}
