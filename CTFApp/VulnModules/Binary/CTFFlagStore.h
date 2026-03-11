//  CTFFlagStore.h
//  ObjC class with enumerable methods — target of challenge B2

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stores challenge flags accessible via ObjC runtime.
/// All methods are enumerable via Frida ObjC.classes / class-dump.
/// This is intentional — ObjC metadata is never stripped.
@interface CTFFlagStore : NSObject

/// Returns the flag for a given challenge ID.
/// Challenge B2: call this via Frida: ObjC.classes.CTFFlagStore['- secretFlagForChallenge:']('B2')
- (NSString *)secretFlagForChallenge:(NSString *)challengeId;

/// Internal method — only accessible if isAuthorized returns YES
- (NSString *)_internalFlagB5Fragment:(NSInteger)part;

@end

NS_ASSUME_NONNULL_END
