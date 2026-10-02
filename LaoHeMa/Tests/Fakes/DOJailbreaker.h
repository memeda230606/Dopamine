#import "DOCore.h"
@interface DOJailbreaker : NSObject
- (DOResult *)run;
- (void)finalize;
- (BOOL)contiguousMappingWorkaroundNeeded;
- (void)applyContiguousMappingWorkaround;
@end
