// Simulator-only harness: uses the real view with an inert controller, no core linked.
#import "LMViewController.h"
@interface LMPreviewController : NSObject <LMJailbreakControlling>
@property(nonatomic) LMState state;
@property(nonatomic, copy) NSString *message;
@property(nonatomic, copy) void (^onChange)(void);
@end
@implementation LMPreviewController
- (void)start { self.state = LMStateRunning; self.message = @"请保持 App 打开。"; if (self.onChange) self.onChange(); }
- (void)applyWorkaround {}
- (void)cancelWorkaround { self.state = LMStateReady; if (self.onChange) self.onChange(); }
@end
static void collectButtons(UIView *view, NSMutableArray *buttons) {
    if ([view isKindOfClass:UIButton.class]) [buttons addObject:view];
    for (UIView *child in view.subviews) collectButtons(child, buttons);
}
@interface LMPreviewAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation LMPreviewAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    LMPreviewController *controller = [LMPreviewController new];
    NSString *phase = NSProcessInfo.processInfo.environment[@"LM_PREVIEW_STATE"] ?: @"ready";
    controller.message = @"";
    if ([phase isEqual:@"active"]) controller.state = LMStateJailbroken;
    else if ([phase isEqual:@"running"]) { controller.state = LMStateRunning; controller.message = @"请保持 App 打开。"; }
    else if ([phase isEqual:@"failed"]) { controller.state = LMStateFailed; controller.message = @"操作未完成。\n请关闭并重新打开 App 后再试。"; }
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    LMViewController *view = [[LMViewController alloc] initWithController:controller];
    self.window.rootViewController = view; [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSMutableArray *buttons = [NSMutableArray new]; collectButtons(view.view, buttons);
        NSCAssert(buttons.count == 1, @"Exactly one main button");
        UIButton *button = buttons.firstObject;
        CGRect frame = [button convertRect:button.bounds toView:view.view];
        NSCAssert(CGRectContainsRect(view.view.bounds, frame), @"Button fits viewport");
        NSCAssert(button.enabled == (controller.state == LMStateReady), @"State gating");
        BOOL pad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
        if (controller.state == LMStateReady) NSCAssert([button.configuration.title isEqual:pad ? @"解放 iPad" : @"解放 iPhone"], @"Device-specific copy");
        NSDictionary *result = @{@"passed":@YES, @"phase":phase, @"button_count":@(buttons.count), @"title":button.configuration.title, @"enabled":@(button.enabled), @"ipad":@(pad), @"width":@(view.view.bounds.size.width)};
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        [[NSJSONSerialization dataWithJSONObject:result options:0 error:nil] writeToFile:[docs stringByAppendingPathComponent:@"ui-result.json"] atomically:YES];
    });
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(LMPreviewAppDelegate.class)); }
}
