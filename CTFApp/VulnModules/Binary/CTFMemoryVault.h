//  CTFMemoryVault.h
//  Challenge B8: Flag exists in memory only — never written to disk.
//  Decrypted at runtime, held for 2 seconds, then zeroed.
//  Frida hint: ObjC.classes.CTFMemoryVault.new()['- decryptAndPresent']()

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface CTFMemoryVault : NSObject

/// Decrypts flag into a heap buffer, logs a notification, waits 2 seconds, zeroes and frees.
/// The flag IOSCTF{B8_fairplay_memory_extracted} exists in memory only during this window.
/// Scan with: Memory.scanSync() for pattern '49 4F 53 43 54 46 7B' (IOSCTF{)
- (void)decryptAndPresent;

/// Trigger the memory window and simultaneously start a scan — convenience for testing
+ (void)triggerAndScan;

@end

NS_ASSUME_NONNULL_END
