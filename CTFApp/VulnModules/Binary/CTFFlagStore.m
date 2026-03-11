//  CTFFlagStore.m
//  Implementation — ObjC runtime attack surface

#import "CTFFlagStore.h"

@implementation CTFFlagStore

- (NSString *)secretFlagForChallenge:(NSString *)challengeId {
    // Challenge B2: this method is callable via Frida ObjC runtime
    // All ObjC method names survive ARM64 compilation and appear in __objc_methnames
    NSDictionary *flags = @{
        @"B2": @"IOSCTF{B2_objc_method_enumerated}",
    };
    return flags[challengeId] ?: @"UNKNOWN_CHALLENGE";
}

// B5 fragments — assembly order hint is in binary strings: "order: 3-1-2"
- (NSString *)_internalFlagB5Fragment:(NSInteger)part {
    switch (part) {
        case 1: return @"class_dump_";
        case 2: return @"assembled}";
        case 3: return @"IOSCTF{B5_";
        default: return @"";
    }
}

@end
