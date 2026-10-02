#import <UIKit/UIKit.h>
#import "LMCoreHost.h"
#import "LMJailbreakController.h"
#import "LMViewController.h"
#import "DOEnvironmentManager.h"

@interface LMAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation LMAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    LMCoreHost *host = (LMCoreHost *)[DOCoreContext sharedContext].host;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[LMViewController alloc] initWithController:[[LMJailbreakController alloc] initWithHost:host]];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        LMCoreHost *host = [LMCoreHost install];
        if ([DOEnvironmentManager sharedManager].isJailbroken) {
            setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/var/jb/sbin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/bin", 1);
            setenv("TERM", "xterm-256color", 1);
        }
        // Diagnostic launch never calls start/run/finalize and never reboots the phone.
        if ([NSProcessInfo.processInfo.environment[@"LAOHEMA_DIAGNOSTICS"] isEqual:@"1"]) [host recordDiagnostics];
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(LMAppDelegate.class));
    }
}
