//  CTFJailbreakDetectorAdvanced.h
//  Challenge B7: Multi-layer jailbreak detection.
//  Each layer corresponds to one bypass step in bypass_b7_multilayer.js.
//  The Frida script must neutralize ALL layers before isDeviceClean returns YES.

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface CTFJailbreakDetectorAdvanced : NSObject

/// Master check — returns YES only if ALL layers pass (no JB detected).
/// B7: All four layers must be individually bypassed via Frida.
+ (BOOL)isDeviceClean;

/// Layer 1: File system checks (NSFileManager)
+ (BOOL)layer1_fileSystemClean;

/// Layer 2: dyld image scan for injected substrate/hooks
+ (BOOL)layer2_dyldImagesClean;

/// Layer 3: fork() syscall — JB devices can fork, stock cannot
+ (BOOL)layer3_forkDenied;

/// Layer 4: ObjC runtime — check for CydiaSubstrate classes
+ (BOOL)layer4_runtimeClean;

/// Returns the B7 flag — only if isDeviceClean returns YES
+ (nullable NSString *)flagIfClean;

@end

NS_ASSUME_NONNULL_END
