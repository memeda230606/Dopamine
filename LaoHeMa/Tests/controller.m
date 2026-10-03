// Tests the real orchestration with inert dependencies; never invokes exploits or reboots.
#import "LMJailbreakController.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"
#import "DOCoreDiagnostics.h"
@implementation DOCoreDiagnostics
+ (NSDictionary *)environmentReport { return @{}; }
@end
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

static int runs, finalizations, workarounds;
static BOOL needsWorkaround;
static NSString *resourceError;
static DOResult *nextResult;
@implementation DOEnvironmentManager
+ (instancetype)sharedManager { static id instance; if (!instance) instance = [self new]; return instance; }
@end
@implementation DOJailbreaker
- (DOResult *)run { runs++; return nextResult; }
- (void)finalize { finalizations++; }
- (BOOL)contiguousMappingWorkaroundNeeded { return needsWorkaround; }
- (void)applyContiguousMappingWorkaround { workarounds++; }
@end
@interface LMTestHost : NSObject
- (NSString *)resourceError;
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update;
- (void)startLogCapture;
@end
@implementation LMTestHost
- (NSString *)resourceError { return resourceError; }
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update {}
- (void)startLogCapture {}
@end
static LMJailbreakController *fresh(void) {
    return [[LMJailbreakController alloc] initWithHost:(id)[LMTestHost new]];
}
static void settle(LMJailbreakController *controller) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while ((controller.state == LMStateRunning || controller.state == LMStateFinishing) && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}
int main(void) {
    @autoreleasepool {
        DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
        environment.isSupported = YES;
        nextResult = [[DOResult alloc] initWithError:nil removed:NO showLogs:NO action:DOCompletionActionNone];
        LMJailbreakController *controller = fresh();
        NSCAssert(controller.state == LMStateReady, @"ready");
        [controller start]; [controller start]; settle(controller);
        NSCAssert(runs == 1 && finalizations == 0 && controller.state == LMStateJailbroken, @"single execution and no completion when not requested");
        environment.isJailbroken = YES; controller = fresh(); [controller start];
        NSCAssert(controller.state == LMStateJailbroken && runs == 1, @"active environment cannot run");
        environment.isJailbroken = NO; environment.isJailbrokenWithOtherJailbreak = YES;
        controller = fresh(); [controller start]; NSCAssert(runs == 1, @"other active environment cannot run");
        environment.isJailbrokenWithOtherJailbreak = NO; environment.isSupported = NO;
        controller = fresh(); [controller start]; NSCAssert(controller.state == LMStateUnsupported && runs == 1, @"unsupported cannot run");
        environment.isSupported = YES; resourceError = @"Missing payload";
        controller = fresh(); [controller start]; NSCAssert(controller.state == LMStateFailed && runs == 1, @"missing resource cannot run");
        resourceError = nil; controller = fresh(); environment.isJailbroken = YES;
        [controller start]; NSCAssert(runs == 1 && controller.state == LMStateJailbroken, @"recheck at click");
        environment.isJailbroken = NO; needsWorkaround = YES;
        controller = fresh(); [controller start]; settle(controller);
        NSCAssert(controller.state == LMStateNeedsWorkaround && runs == 1 && workarounds == 0, @"workaround requires explicit action");
        [controller cancelWorkaround]; NSCAssert(controller.state == LMStateReady, @"cancel permits another preflight");
        [controller start]; settle(controller); [controller applyWorkaround]; settle(controller);
        NSCAssert(workarounds == 1 && runs == 1 && controller.state == LMStateFailed, @"workaround requests reopen without chained execution");
        needsWorkaround = NO;
        nextResult = [[DOResult alloc] initWithError:[NSError errorWithDomain:@"test" code:1 userInfo:nil] removed:NO showLogs:YES action:DOCompletionActionUserspaceReboot];
        controller = fresh(); [controller start]; settle(controller); [controller start];
        NSCAssert(controller.state == LMStateFailed && runs == 2 && finalizations == 0, @"failure is terminal and cannot finalize");
        nextResult = [[DOResult alloc] initWithError:nil removed:NO showLogs:NO action:DOCompletionActionUserspaceReboot];
        controller = fresh(); [controller start]; settle(controller);
        NSCAssert(runs == 3 && finalizations == 1 && controller.state == LMStateFinishing, @"completion runs once; allow asynchronous reboot handoff");
        puts("{\"passed\":true,\"checks\":[\"duplicate-click\",\"active-environment\",\"other-environment\",\"unsupported\",\"missing-resource\",\"click-recheck\",\"workaround-confirm-cancel\",\"failure-no-retry\",\"completion-policy\"]}");
    }
}
