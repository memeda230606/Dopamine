#import "DOEngine.h"
#import "DOCommandLine.h"
static BOOL active,supported=YES,resources=YES,workaround,fail;
static int runs,prepares,finishes;
@implementation DOEngine
+ (BOOL)isActive{return active;}
+ (BOOL)isSupported{return supported;}
+ (NSDictionary *)diagnostics{return @{@"resources_complete":@(resources)};}
- (BOOL)contiguousMappingWorkaroundNeeded{return workaround;}
- (void)applyContiguousMappingWorkaround{prepares++;}
- (DOResult *)run{runs++;return [[DOResult alloc]initWithError:fail?[NSError errorWithDomain:@"test" code:1 userInfo:nil]:nil removed:NO showLogs:NO action:DOCompletionActionUserspaceReboot];}
- (void)finalize{finishes++;}
@end
@interface TestHost:NSObject
@end
@implementation TestHost
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update{}
@end
static int command(const char *arg) { const char *argv[]={"test",arg};int result=-1;NSCAssert(DOHandleCommandLine(2,argv,&result),@"handled");return result; }
int main(void) { @autoreleasepool {
    [DOCoreContext installHost:(id)[TestHost new]];
    NSCAssert(command("--core-status")==0 && !runs,@"readonly status");
    active=YES;NSCAssert(command("--core-run")==0 && !runs,@"already active");active=NO;
    supported=NO;NSCAssert(command("--core-run")==69 && !runs,@"unsupported");supported=YES;
    resources=NO;NSCAssert(command("--core-run")==66 && !runs,@"missing resources");resources=YES;
    workaround=YES;NSCAssert(command("--core-run")==75 && !prepares && !runs,@"explicit preparation needed");
    NSCAssert(command("--core-prepare")==75 && prepares==1 && !runs,@"prepare does not chain run");workaround=NO;
    fail=YES;NSCAssert(command("--core-run")==1 && runs==1 && !finishes,@"failure cannot finalize");fail=NO;
    NSCAssert(command("--core-run")==0 && runs==2 && finishes==1,@"same full engine entry");
    NSCAssert(command("--core-unknown")==64 && runs==2,@"invalid CLI");
    const char *argv[]={"app"};int exitCode=0;NSCAssert(!DOHandleCommandLine(1,argv,&exitCode),@"normal app launch remains UI");
    puts("{\"passed\":true,\"cli_contracts\":9}");
} }
