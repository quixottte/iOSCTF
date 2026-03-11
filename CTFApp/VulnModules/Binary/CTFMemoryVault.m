//  CTFMemoryVault.m
//  B8: Memory-only flag. Key derived from device UDID constant (simplified to static key here).

#import "CTFMemoryVault.h"
#import <CommonCrypto/CommonCrypto.h>
#include <string.h>
#include <stdlib.h>

// AES-128-ECB encrypted form of "IOSCTF{B8_fairplay_memory_extracted}\0..."
// Encrypted with key: "CTF_B8_KEY_12345" (16 bytes)
// Generated with: python3 -c "from Crypto.Cipher import AES; ..."
// Key is visible in Ghidra — the challenge is MEMORY forensics, not key recovery.
static const uint8_t kEncryptedFlag[] = {
    0x4B,0x72,0x8A,0x1C,0xE3,0x5F,0x97,0x2D,
    0x8B,0x4E,0xF1,0x63,0x2A,0x9C,0x57,0xE8,
    0x3D,0x7F,0xA2,0x1B,0xC6,0x48,0xF3,0x9E,
    0x52,0x8D,0x17,0xB4,0x6A,0xC1,0x3F,0x85,
    0x9B,0x26,0xE7,0x4C,0xA8,0x13,0x5E,0xD2,
    0x7A,0xC4,0x91,0x3B,0xF6,0x28,0xA5,0x6C
};
static const size_t kEncryptedFlagLen = sizeof(kEncryptedFlag);
static const uint8_t kDecryptionKey[] = "CTF_B8_KEY_12345";  // visible in Ghidra __TEXT

@implementation CTFMemoryVault

- (void)decryptAndPresent {
    size_t bufSize = kEncryptedFlagLen + kCCBlockSizeAES128;
    uint8_t *plaintext = (uint8_t *)malloc(bufSize);
    if (!plaintext) return;

    size_t outLen = 0;
    CCCryptorStatus status = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES,
        kCCOptionECBMode | kCCOptionPKCS7Padding,
        kDecryptionKey, kCCKeySizeAES128,
        NULL,
        kEncryptedFlag, kEncryptedFlagLen,
        plaintext, bufSize,
        &outLen
    );

    if (status == kCCSuccess) {
        // ═══════════════════════════════════════════════════════════
        // B8: FLAG IS IN plaintext BUFFER RIGHT NOW
        // Frida memory scan window: ~2 seconds from this point
        //
        // Method 1 — Hook approach:
        //   Hook CTFMemoryVault '- decryptAndPresent', read plaintext on entry to memset
        //
        // Method 2 — Scan approach (while this thread sleeps):
        //   Process.enumerateRanges('r--').forEach(r => {
        //     Memory.scanSync(r.base, r.size, '49 4F 53 43 54 46 7B')
        //   })
        //
        // 49 4F 53 43 54 46 7B = "IOSCTF{" in ASCII hex
        // ═══════════════════════════════════════════════════════════
        NSLog(@"[CTF] B8: Memory window OPEN — scan now for IOSCTF{ (0x49 0x4F 0x53...)");
        [NSThread sleepForTimeInterval:2.0];
        NSLog(@"[CTF] B8: Zeroing memory — window CLOSED");
    }

    // Deliberately zero the memory — flag gone after this
    memset(plaintext, 0, bufSize);
    free(plaintext);
}

+ (void)triggerAndScan {
    CTFMemoryVault *vault = [CTFMemoryVault new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [vault decryptAndPresent];
    });
}

@end
