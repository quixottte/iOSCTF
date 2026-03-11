//  CTFJailbreakDetectorAdvanced.m
//  B7 multi-layer JB detection — each method is independently hookable via Frida.

#import "CTFJailbreakDetectorAdvanced.h"
#include <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>

// dyld image count/name functions
extern uint32_t _dyld_image_count(void);
extern const char* _dyld_get_image_name(uint32_t index);

@implementation CTFJailbreakDetectorAdvanced

+ (BOOL)isDeviceClean {
    // All four layers must pass — Frida must hook each independently
    return [self layer1_fileSystemClean]
        && [self layer2_dyldImagesClean]
        && [self layer3_forkDenied]
        && [self layer4_runtimeClean];
}

// ── Layer 1: File system ──────────────────────────────────────────────────────
+ (BOOL)layer1_fileSystemClean {
    NSArray *jbPaths = @[
        @"/Applications/Cydia.app",
        @"/private/var/lib/apt/",
        @"/private/var/lib/cydia",
        @"/bin/bash",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/.installed_unc0ver",
        @"/.bootstrapped_electra",
        @"/var/jb"
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in jbPaths) {
        // B7 Layer 1: hook NSFileManager fileExistsAtPath: → return NO for these paths
        if ([fm fileExistsAtPath:path]) return NO;
    }
    // Also check for writable /private — sandbox violation indicates JB
    NSString *testPath = [NSString stringWithFormat:@"/private/jb_test_%@", [[NSUUID UUID] UUIDString]];
    if ([@"test" writeToFile:testPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:testPath error:nil];
        return NO;
    }
    return YES;
}

// ── Layer 2: dyld images ──────────────────────────────────────────────────────
+ (BOOL)layer2_dyldImagesClean {
    NSArray *suspiciousKeywords = @[@"substrate", @"cydia", @"cynject", @"libhooker",
                                    @"dopamine", @"substitute", @"safariloader"];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        // B7 Layer 2: hook _dyld_get_image_name → return benign path for JB libraries
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *nameStr = [[NSString stringWithUTF8String:name] lowercaseString];
        for (NSString *kw in suspiciousKeywords) {
            if ([nameStr containsString:kw]) return NO;
        }
    }
    return YES;
}

// ── Layer 3: fork() ───────────────────────────────────────────────────────────
+ (BOOL)layer3_forkDenied {
    // Stock iOS: fork() returns -1 (EPERM) — processes cannot fork
    // Jailbroken: fork() succeeds (returns 0 in child, >0 in parent)
    // B7 Layer 3: hook fork() → return -1 to simulate stock behavior
    pid_t pid = fork();
    if (pid == 0) {
        // We're in the child — JB environment. Kill child, return failure.
        exit(0);
    }
    if (pid > 0) {
        // Parent — fork succeeded → JB detected
        waitpid(pid, NULL, 0);
        return NO;
    }
    // pid == -1 → fork denied → stock device (or hooked)
    return YES;
}

// ── Layer 4: ObjC runtime class check ────────────────────────────────────────
+ (BOOL)layer4_runtimeClean {
    NSArray *jbClasses = @[@"CydiaSubstrate", @"SBSLocalNotificationClient",
                           @"SubstrateHook", @"SubstrateLoader"];
    for (NSString *className in jbClasses) {
        // B7 Layer 4: hook NSClassFromString → return nil for these class names
        if (NSClassFromString(className) != nil) return NO;
    }
    // Also check for substrate via dlopen
    void *handle = dlopen("/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", RTLD_LAZY | RTLD_NOLOAD);
    if (handle) {
        dlclose(handle);
        return NO;
    }
    return YES;
}

// ── Flag gate ─────────────────────────────────────────────────────────────────
+ (nullable NSString *)flagIfClean {
    if ([self isDeviceClean]) {
        return @"IOSCTF{B7_multilayer_jb_broken}";
    }
    return nil;
}

@end
