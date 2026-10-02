#import <Foundation/Foundation.h>
#import "DOCore.h"

NS_ASSUME_NONNULL_BEGIN
@interface LMCoreHost : NSObject <DOCoreHost>
+ (instancetype)install;
- (nullable NSString *)resourceError;
- (void)recordDiagnostics;
- (void)startLogCapture;
@end
NS_ASSUME_NONNULL_END
