//  CTFVault.h — Target of B6 (method swizzling) and B8 (memory extraction)

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface CTFVault : NSObject

/// Always returns "ACCESS_DENIED" unless isAuthorized is swizzled to return YES.
/// Challenge B6: swizzle isAuthorized, then call this.
- (NSString *)retrieveSecret;

/// Returns NO by default. Swizzle this to return YES.
- (BOOL)isAuthorized;

/// Decrypts flag into memory, holds for 2 seconds, then zeros it.
/// Challenge B8: scan memory for IOSCTF{ pattern during the window.
- (void)decryptAndPresent;

@end

NS_ASSUME_NONNULL_END
