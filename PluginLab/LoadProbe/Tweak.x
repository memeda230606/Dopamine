#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>

@interface PLResults : NSObject
+ (void)record:(NSString *)name value:(NSDictionary *)value;
@end

__attribute__((visibility("default"))) int PLLoadProbeMarker(void) { return 20261002; }

%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.mmd.PluginLab"]) return;
    Dl_info info = {0};
    dladdr((void *)&PLLoadProbeMarker, &info);
    Class results = NSClassFromString(@"PLResults");
    [results record:@"load" value:@{@"loaded": @YES,
        @"image": info.dli_fname ? @(info.dli_fname) : @"unknown", @"pid": @(getpid())}];
}
