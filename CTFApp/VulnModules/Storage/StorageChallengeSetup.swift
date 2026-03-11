//  StorageChallengeSetup.swift
//  Plants vulnerable data for all storage challenges at app startup.

import Foundation
import Security

@objc class StorageChallengeSetup: NSObject {

    // Called from CTFAppApp.init()
    static func plant() {
        plantS1()
        plantS2()
        plantS3()
        plantS4()
        plantS5()
        // S6: planted in ChallengeDetailView.triggerChallengeSetup() on navigation
        plantS7()
        plantS8()
    }

    // MARK: - S1: NSUserDefaults

    @objc static func plantS1() {
        // VULN: Storing a secret in NSUserDefaults — world-readable plist on device
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "ctf_s1_flag") == nil {
            defaults.set("IOSCTF{S1_defaults_are_not_secrets}", forKey: "ctf_s1_flag")
            defaults.synchronize()
        }
    }

    // MARK: - S2: Plist in Documents

    static func plantS2() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let configURL = docs.appendingPathComponent("config.plist")
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }

        // VULN: Writing credentials to Documents — accessible via file sharing / iMazing
        let config: NSDictionary = [
            "api_base_url": "https://api.internal.example.com",
            "admin_username": "ctfadmin",
            "admin_password": "hunter2",
            "secret_flag": "IOSCTF{S2_plist_exposed_in_documents}",
            "debug_mode": true
        ]
        config.write(to: configURL, atomically: true)
    }

    // MARK: - S3: SQLite

    static func plantS3() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbURL = docs.appendingPathComponent("events.sqlite")
        guard !FileManager.default.fileExists(atPath: dbURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let create = """
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT,
                payload TEXT,
                timestamp INTEGER
            );
        """
        sqlite3_exec(db, create, nil, nil, nil)

        // VULN: Flag stored in plaintext SQLite with no encryption
        let rows = [
            ("user_login",    "user=ctfuser&session=abc123"),
            ("api_request",   "GET /api/v1/profile"),
            ("secret_event",  "IOSCTF{S3_sqlite_rows_never_lie}"),     // the flag row
            ("user_logout",   "session=abc123"),
        ]
        for (type, payload) in rows {
            let insert = "INSERT INTO events (type, payload, timestamp) VALUES ('\(type)', '\(payload)', \(Int(Date().timeIntervalSince1970)));"
            sqlite3_exec(db, insert, nil, nil, nil)
        }
    }

    // MARK: - S4: Keychain with kSecAttrAccessibleAlways

    static func plantS4() {
        let service = "com.iosctf.app"
        let account = "ctf_s4_secret"

        // Check if already planted
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess { return }

        // VULN: kSecAttrAccessibleAlways — readable without device unlock, accessible to keychain-dumper
        let flagData = "IOSCTF{S4_keychain_accessible_always_fail}".data(using: .utf8)!
        let add: [CFString: Any] = [
            kSecClass:                  kSecClassGenericPassword,
            kSecAttrService:            service,
            kSecAttrAccount:            account,
            kSecValueData:              flagData,
            kSecAttrAccessible:         kSecAttrAccessibleAlways,   // ← the vulnerability
            kSecAttrLabel:              "CTF Challenge S4"
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    // MARK: - S5: CoreData (stubbed — set up in CoreDataManager.swift)

    static func plantS5() {
        CoreDataManager.shared.plantS5Flag()
    }

    // MARK: - S7: XOR-encrypted vault

    static func plantS7() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vaultURL = docs.appendingPathComponent("vault.enc")
        guard !FileManager.default.fileExists(atPath: vaultURL.path) else { return }

        // VULN: Single-byte XOR — the key (0x4A) is a string constant in this binary
        // Ghidra: search for "vault.enc" string, XOR key is nearby
        let xorKey: UInt8 = 0x4A   // 'J' — intentionally visible in binary
        let plaintext = "IOSCTF{S7_xor_is_not_encryption}"
        let encrypted = Data(plaintext.utf8.map { $0 ^ xorKey })
        try? encrypted.write(to: vaultURL)
    }

    // MARK: - S8: Shared Keychain group

    static func plantS8() {
        let account = "ctf_s8_shared_secret"

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      "com.iosctf.shared.service",
            kSecAttrAccount:      account,
            kSecAttrAccessGroup:  "com.iosctf.shared",   // ← shared across apps with same Team ID
            kSecReturnData:       true
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess { return }

        let flagData = "IOSCTF{S8_shared_keychain_group_pivot}".data(using: .utf8)!
        let add: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     "com.iosctf.shared.service",
            kSecAttrAccount:     account,
            kSecAttrAccessGroup: "com.iosctf.shared",
            kSecValueData:       flagData,
            kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(add as CFDictionary, nil)
    }
}
