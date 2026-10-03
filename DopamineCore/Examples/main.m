#import <Foundation/Foundation.h>
#import "DOEngine.h"
#import "DOCommandLine.h"
// A headless host: place Runtime beside the executable, or set DO_RESOURCES.
@interface CLIHost : NSObject <DOCoreHost>
@end
@implementation CLIHost
- (NSDictionary *)settingsSnapshot { return @{@"appJITEnabled":@YES,@"tweakInjectionEnabled":@(!DOEngine.isBootstrapped || DOEngine.isTweakInjectionEnabled)}; }
- (void)setSetting:(id)value forKey:(NSString *)key {}
- (NSString *)resourceDirectory { return NSProcessInfo.processInfo.environment[@"DO_RESOURCES"] ?: [NSProcessInfo.processInfo.arguments[0].stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Runtime"]; }
- (NSString *)documentsDirectory { return NSTemporaryDirectory(); }
- (NSString *)applicationIdentifier { return @"com.mmd.DopamineCLI"; }
- (NSString *)applicationVersion { return [NSDictionary dictionaryWithContentsOfFile:[self.resourceDirectory stringByAppendingPathComponent:@"RuntimeManifest.plist"]][@"runtime_version"] ?: @"unknown"; }
- (NSString *)applicationBuild { return @"1"; }
- (NSArray *)packageManagers { return [[NSArray arrayWithContentsOfFile:[self.resourceDirectory stringByAppendingPathComponent:@"PkgManagers.plist"]] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"Key == %@",@"org.coolstar.SileoStore"]]; }
- (NSData *)bootLogoData { return nil; }
- (NSString *)localizedString:(NSString *)key { return key; }
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update { fprintf(stderr,"%s\n",message.UTF8String); }
- (BOOL)allowsUserspaceReboot { return YES; }
@end
int main(int argc,char **argv) {
    @autoreleasepool {
        [DOCoreContext installHost:[CLIHost new]];
        int status=64;
        if(!DOHandleCommandLine(argc,(const char *const *)argv,&status))fprintf(stderr,"Use --core-status, --core-run or --core-prepare\n");
        return status;
    }
}
