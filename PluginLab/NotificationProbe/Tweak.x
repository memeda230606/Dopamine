#import <Foundation/Foundation.h>

@interface PLResults : NSObject
+ (void)record:(NSString *)name value:(NSDictionary *)value;
@end

static id PLNotificationObserver;
%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.mmd.PluginLab"]) return;
    PLNotificationObserver = [NSNotificationCenter.defaultCenter addObserverForName:@"com.mmd.PluginLab.Ping"
        object:nil queue:nil usingBlock:^(NSNotification *note) {
            Class results = NSClassFromString(@"PLResults");
            [results record:@"notification" value:@{@"received": @YES, @"nonce": note.userInfo[@"nonce"] ?: @""}];
        }];
}
