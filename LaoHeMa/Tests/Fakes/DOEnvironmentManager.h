#import <Foundation/Foundation.h>
@interface DOEnvironmentManager : NSObject
+ (instancetype)sharedManager;
@property BOOL isJailbroken;
@property BOOL isJailbrokenWithOtherJailbreak;
@property BOOL isSupported;
@end
