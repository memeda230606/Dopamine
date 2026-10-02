#import <Foundation/Foundation.h>
#import "DOCore.h"
@interface DOAppCoreHost : NSObject <DOCoreHost>
+ (void)install;
+ (NSString *)summaryForNoRebootReport:(NSDictionary *)report;
@end
