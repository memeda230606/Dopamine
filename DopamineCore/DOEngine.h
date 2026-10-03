#import "DOCore.h"
NS_ASSUME_NONNULL_BEGIN
// Public host API. No UI, exploit, private-framework or backend struct headers.
@interface DOEngine : NSObject
+ (BOOL)isActive;
+ (BOOL)isOwnedEnvironment;
+ (BOOL)isSupported;
+ (BOOL)isBootstrapped;
+ (BOOL)isTweakInjectionEnabled;
+ (NSDictionary *)diagnostics;
- (BOOL)contiguousMappingWorkaroundNeeded;
- (void)applyContiguousMappingWorkaround;
- (DOResult *)run;
- (void)finalize;
@end
NS_ASSUME_NONNULL_END
