//  CTFAntiDebug.m

#import "CTFAntiDebug.h"
#import <sys/types.h>

// sys/ptrace.h is intentionally absent from the iOS SDK — Apple removed it
// to discourage anti-debug techniques. The syscall still exists at runtime.
// We declare the prototype manually so the compiler accepts the call.
// This is standard practice in iOS anti-debug implementations.
int ptrace(int request, pid_t pid, caddr_t addr, int data);

// PT_DENY_ATTACH = 31 on Darwin/iOS (from XNU source: bsd/sys/ptrace.h)
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

static BOOL sAntiDebugInstalled = NO;
static BOOL sDebuggerBlocked    = NO;

@implementation CTFAntiDebug

+ (void)installAntiDebug {
    if (sAntiDebugInstalled) return;
    sAntiDebugInstalled = YES;

    // VULN: This call kills the process if a debugger is attached.
    // Challenge B3: hook ptrace() to intercept this call before it fires.
    // When hooked correctly: args[0] == 31 (PT_DENY_ATTACH) → neutralize
    int result = ptrace(PT_DENY_ATTACH, 0, 0, 0);
    sDebuggerBlocked = (result == 0);  // 0 = success = no debugger at install time
}

+ (nullable NSString *)revealFlagIfSafe {
    // If ptrace succeeded (or was neutralized by Frida hook), reveal the flag
    if (sDebuggerBlocked) {
        return @"IOSCTF{B3_ptrace_deny_attach_bypassed}";
    }
    return nil;
}

@end
