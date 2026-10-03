#import <Foundation/Foundation.h>
// Existing runtime access only. This module never invokes exploits or writes kernel memory.
@interface DORuntimeClient : NSObject
+ (instancetype)sharedClient;
- (NSDictionary *)status;
- (int)trustFile:(NSString *)path;
- (NSDictionary *)readKernelHeader;
@end
