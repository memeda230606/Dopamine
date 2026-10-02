#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Read-only inspection: never invokes an exploit, installs files, or restarts.
@interface DOCoreDiagnostics : NSObject
+ (NSDictionary *)environmentReport;
@end
NS_ASSUME_NONNULL_END
