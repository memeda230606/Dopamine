#import "LMJailbreakController.h"
#import "LMCoreHost.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"

@interface LMJailbreakController ()
@property(nonatomic, readwrite) LMState state;
@property(nonatomic, copy, readwrite) NSString *message;
@property(nonatomic, strong) LMCoreHost *host;
@property(nonatomic, strong) DOJailbreaker *jailbreaker;
@end

@implementation LMJailbreakController
- (instancetype)initWithHost:(LMCoreHost *)host {
    if ((self = [super init])) {
        _host = host; _message = @"";
        NSString *error = host.resourceError;
        if (error) { _state = LMStateFailed; _message = error; }
        else if ([DOEnvironmentManager sharedManager].isJailbroken || [DOEnvironmentManager sharedManager].isJailbrokenWithOtherJailbreak) _state = LMStateJailbroken;
        else if (![DOEnvironmentManager sharedManager].isSupported) {
            _state = LMStateUnsupported; _message = @"当前设备或系统版本不受支持。";
        } else _state = LMStateReady;
    }
    return self;
}
- (void)setState:(LMState)state message:(NSString *)message {
    NSAssert(NSThread.isMainThread, @"UI state must change on the main thread");
    self.state = state; self.message = message;
    if (self.onChange) self.onChange();
}
- (void)start {
    NSAssert(NSThread.isMainThread, @"Start from the UI thread");
    if (self.state != LMStateReady) return;
    // Recheck immediately before execution; never run a second chain in an active environment.
    if ([DOEnvironmentManager sharedManager].isJailbroken || [DOEnvironmentManager sharedManager].isJailbrokenWithOtherJailbreak) {
        [self setState:LMStateJailbroken message:@""]; return;
    }
    [self setState:LMStateRunning message:@"请保持 App 打开。"];
    [self.host startLogCapture];
    self.jailbreaker = [DOJailbreaker new];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if ([self.jailbreaker contiguousMappingWorkaroundNeeded]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setState:LMStateNeedsWorkaround message:@"此设备需要先准备连续内存。继续后桌面会重新启动，请随后重新打开老河马。"];
            });
            return;
        }
        DOResult *result = [self.jailbreaker run];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result.error || result.didRemoveJailbreak) {
                NSString *error = result.error.localizedDescription ?: @"操作未完成。";
                [self.host log:error debug:YES update:NO];
                // Core primitives are process-global. Do not retry a partial chain in this process.
                [self setState:LMStateFailed message:[error stringByAppendingString:@"\n请关闭并重新打开 App 后再试。"]];
                return;
            }
            if (result.completionAction == DOCompletionActionUserspaceReboot) {
                [self setState:LMStateFinishing message:@"已完成，正在重启用户空间…"];
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    [self.jailbreaker finalize];
                    // Give the system time to complete an asynchronous reboot request.
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [self setState:LMStateFailed message:@"流程已完成，但用户空间尚未重启。请查看运行日志。"];
                    });
                });
            } else {
                [self setState:LMStateJailbroken message:@""];
            }
        });
    });
}
- (void)applyWorkaround {
    if (self.state != LMStateNeedsWorkaround) return;
    [self setState:LMStateRunning message:@"正在准备环境，随后请重新打开 App…"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.jailbreaker applyContiguousMappingWorkaround];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setState:LMStateFailed message:@"环境准备已结束，请重新打开 App。"];
        });
    });
}
- (void)cancelWorkaround { if (self.state == LMStateNeedsWorkaround) [self setState:LMStateReady message:@""]; }
@end
