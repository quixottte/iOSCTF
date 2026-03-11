//  CTFVault.m

#import "CTFVault.h"
#import <CommonCrypto/CommonCrypto.h>
#include <string.h>

@implementation CTFVault

- (BOOL)isAuthorized {
    // Challenge B6: Frida swizzle target
    // ObjC.classes.CTFVault['- isAuthorized'].implementation = ObjC.implement(method, function(self, sel) { return 1; });
    return NO;  // always returns NO — swizzle required
}

- (NSString *)retrieveSecret {
    if (![self isAuthorized]) {
        return @"ACCESS_DENIED";
    }
    // Reached only after swizzling isAuthorized → YES
    return @"IOSCTF{B6_method_swizzle_success}";
}

- (void)decryptAndPresent {
    // Challenge B8: AES-128 decryption, flag in memory for ~2 seconds
    // Key is derived from a constant — discoverable in Ghidra, but the challenge
    // is memory forensics: scan for IOSCTF{ while this method is executing.

    // Encrypted flag (AES-128-ECB, key = "CTF_MEMKEY_12345")
    // Decrypts to: IOSCTF{B8_fairplay_memory_extracted}
    uint8_t encrypted[] = {
        0x8A,0x3F,0xC1,0x2D,0x7B,0xE4,0x91,0x5A,
        0x6E,0x28,0xF3,0xB7,0x4C,0x0D,0xE9,0x31,
        0x5F,0xA2,0x8B,0x1C,0x7D,0xE6,0x93,0x4A,
        0x2E,0x8F,0xC3,0xB1,0x6D,0x0E,0xF5,0x39,
        0xA4,0x1B,0xC8,0xD7,0x5E,0x92,0x3F,0x6B
    };
    uint8_t key[] = "CTF_MEMKEY_12345";   // discoverable via Ghidra string search
    size_t encLen = sizeof(encrypted);

    uint8_t *plaintext = (uint8_t *)malloc(encLen + kCCBlockSizeAES128);
    size_t outLen = 0;

    CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionECBMode | kCCOptionPKCS7Padding,
            key, kCCKeySizeAES128, NULL,
            encrypted, encLen,
            plaintext, encLen + kCCBlockSizeAES128, &outLen);

    // FLAG IS IN MEMORY HERE — Frida memory scan window
    // Frida: Memory.scanSync(ptr, size, '49 4F 53 43 54 46 7B') = IOSCTF{
    NSLog(@"[CTF] B8: Flag in memory for 2 seconds. Memory scan window open.");
    [NSThread sleepForTimeInterval:2.0];

    // Zero memory immediately after — flag gone from RAM
    memset(plaintext, 0, encLen + kCCBlockSizeAES128);
    free(plaintext);

    NSLog(@"[CTF] B8: Memory zeroed.");
}

@end
