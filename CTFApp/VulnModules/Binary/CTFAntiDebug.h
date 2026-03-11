//  CTFAntiDebug.h
//  Anti-debugging implementation — target of challenge B3

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CTFAntiDebug : NSObject

/// Called at app startup. Installs ptrace(PT_DENY_ATTACH) anti-debug.
/// Challenge B3: hook ptrace() to neutralize this before it fires.
+ (void)installAntiDebug;

/// Only reveals flag if ptrace check passed (i.e., hook neutralized it).
/// Challenge B3: hook ptrace, then call this.
+ (nullable NSString *)revealFlagIfSafe;

@end

NS_ASSUME_NONNULL_END
