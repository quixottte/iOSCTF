//  BinaryChallengeSetup.swift
//  Plants binary challenge state at startup

import Foundation

// B1: The flag is a string constant below — visible via strings/Ghidra
// Challenge B1: strings CTFApp | grep IOSCTF
// swiftlint:disable line_length
private let _b1Flag = "IOSCTF{B1_strings_command_wins}"   // visible in __TEXT,__cstring

class BinaryChallengeSetup: NSObject {

    static func plant() {
        installAntiDebug()
        plantB5Fragments()
    }

    private static func installAntiDebug() {
        // B3: Install ptrace anti-debug at startup
        CTFAntiDebug.installAntiDebug()
    }

    private static func plantB5Fragments() {
        // B5: Fragment order hint stored as a string in the binary
        // strings CTFApp | grep "order:" → "order: 3-1-2"
        let _assemblyOrder = "order: 3-1-2"  // noqa — intentional
        _ = _assemblyOrder                    // suppress unused warning
    }
}

// B7: Multi-layer JB detection (ObjC — defined in JailbreakDetectorAdvanced.m)
// See VulnModules/Binary/JailbreakDetectorAdvanced.[h|m]
