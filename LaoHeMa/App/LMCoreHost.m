#import "LMCoreHost.h"
#import "DOCoreDiagnostics.h"
#import "DOEnvironmentManager.h"
#import <os/log.h>
#import <fcntl.h>
#import <unistd.h>

@interface LMCoreHost ()
@property(nonatomic, copy) NSString *documents;
@property(nonatomic, copy) NSString *preferencesPath;
@property(nonatomic, strong) NSMutableDictionary *settings;
@property(nonatomic, strong) NSFileHandle *logFile;
@property(nonatomic, strong) dispatch_source_t outputSource;
@end

@implementation LMCoreHost
+ (instancetype)install {
    LMCoreHost *host = [self new];
    // Capture container paths before the core changes credentials and HOME.
    host.documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    [NSFileManager.defaultManager createDirectoryAtPath:host.documents withIntermediateDirectories:YES attributes:nil error:nil];
    host.preferencesPath = [host.documents stringByAppendingPathComponent:@"settings.plist"];
    host.settings = [[NSDictionary dictionaryWithContentsOfFile:host.preferencesPath] mutableCopy] ?: [NSMutableDictionary new];
    NSString *logPath = [host.documents stringByAppendingPathComponent:@"latest.log"];
    NSString *previous = [host.documents stringByAppendingPathComponent:@"previous.log"];
    if ([NSFileManager.defaultManager fileExistsAtPath:logPath]) {
        [NSFileManager.defaultManager removeItemAtPath:previous error:nil];
        [NSFileManager.defaultManager moveItemAtPath:logPath toPath:previous error:nil];
    }
    [NSFileManager.defaultManager createFileAtPath:logPath contents:nil attributes:@{NSFilePosixPermissions:@0600}];
    host.logFile = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [DOCoreContext installHost:host];
    return host;
}
- (NSDictionary *)settingsSnapshot {
    @synchronized(self) {
        NSMutableDictionary *snapshot = [self.settings mutableCopy];
        // Keep upstream exploit selection automatic: no device-specific override.
        [snapshot removeObjectsForKeys:@[@"selectedKernelExploit", @"selectedPACBypass", @"selectedPPLBypass"]];
        snapshot[@"removeJailbreakEnabled"] = @NO;
        snapshot[@"idownloadEnabled"] = @NO;
        snapshot[@"bootlogoEnabled"] = @NO;
        snapshot[@"appJITEnabled"] = @YES;
        // Preserve an existing safe-mode choice; a fresh bootstrap uses upstream defaults.
        DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
        snapshot[@"tweakInjectionEnabled"] = @(!environment.isBootstrapped || environment.isTweakInjectionEnabled);
        return snapshot;
    }
}
- (void)setSetting:(id)value forKey:(NSString *)key {
    @synchronized(self) {
        self.settings[key] = value;
        [self.settings writeToFile:self.preferencesPath atomically:YES];
    }
}
- (NSString *)resourceDirectory { return NSBundle.mainBundle.bundlePath; }
- (NSString *)documentsDirectory { return self.documents; }
- (NSString *)applicationIdentifier { return NSBundle.mainBundle.bundleIdentifier; }
// The runtime version must stay tied to Dopamine, independently of our UI version.
- (NSString *)applicationVersion { return NSBundle.mainBundle.infoDictionary[@"LMRuntimeVersion"]; }
- (NSString *)applicationBuild { return NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]; }
- (NSArray *)packageManagers {
    NSArray *managers = [NSArray arrayWithContentsOfFile:[self.resourceDirectory stringByAppendingPathComponent:@"PkgManagers.plist"]];
    // First bootstrap gets Sileo; existing installations retain their package managers.
    return [managers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"Key == %@", @"org.coolstar.SileoStore"]];
}
- (NSData *)bootLogoData { return nil; }
- (NSString *)localizedString:(NSString *)key {
    NSString *path = [NSBundle.mainBundle pathForResource:@"zh-Hans" ofType:@"lproj"];
    NSBundle *chinese = path ? [NSBundle bundleWithPath:path] : NSBundle.mainBundle;
    return [chinese localizedStringForKey:key value:key table:nil];
}
- (BOOL)allowsUserspaceReboot { return YES; }
- (void)startLogCapture {
    if (self.outputSource) return;
    int descriptors[2];
    if (pipe(descriptors) != 0) return;
    int savedOut = dup(STDOUT_FILENO), savedErr = dup(STDERR_FILENO);
    fflush(NULL);
    if (savedOut < 0 || savedErr < 0 || fcntl(descriptors[0], F_SETFL, O_NONBLOCK) < 0 ||
        dup2(descriptors[1], STDOUT_FILENO) < 0 || dup2(descriptors[1], STDERR_FILENO) < 0) {
        if (savedOut >= 0) { dup2(savedOut, STDOUT_FILENO); close(savedOut); }
        if (savedErr >= 0) { dup2(savedErr, STDERR_FILENO); close(savedErr); }
        close(descriptors[0]); close(descriptors[1]); return;
    }
    close(savedOut); close(savedErr); close(descriptors[1]);
    setvbuf(stdout, NULL, _IONBF, 0); setvbuf(stderr, NULL, _IONBF, 0);
    int reader = descriptors[0];
    self.outputSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, reader, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_event_handler(self.outputSource, ^{
        char buffer[4096]; ssize_t length;
        while ((length = read(reader, buffer, sizeof(buffer))) > 0) {
            NSData *data = [NSData dataWithBytes:buffer length:(NSUInteger)length];
            NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (message) [self log:message debug:YES update:NO];
            else @synchronized(self) {
                @try { [self.logFile writeData:data]; } @catch (NSException *exception) {}
            }
        }
    });
    dispatch_source_set_cancel_handler(self.outputSource, ^{ close(reader); });
    dispatch_resume(self.outputSource);
}
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.mmd.LaoHeMa", "Jailbreak"); });
    os_log_with_type(log, OS_LOG_TYPE_DEFAULT, "%{public}s", message.UTF8String);
    @synchronized(self) {
        @try { [self.logFile writeData:[[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]]; }
        @catch (NSException *exception) { /* Unified logging remains available. */ }
    }
}
- (NSString *)resourceError {
    if (![NSString instancesRespondToSelector:NSSelectorFromString(@"numericalVersionRepresentation")])
        return @"核心组件不完整，请重新安装。";
    NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:[self.resourceDirectory stringByAppendingPathComponent:@"RuntimeManifest.plist"]];
    if (![manifest[@"required_files"] count]) return @"运行资源清单缺失，请重新安装。";
    for (NSString *path in manifest[@"required_files"]) {
        if (![NSFileManager.defaultManager fileExistsAtPath:[[DOCoreContext sharedContext] resourcePath:path]])
            return [NSString stringWithFormat:@"缺少运行资源：%@", path];
    }
    return nil;
}
- (void)recordDiagnostics {
    NSMutableDictionary *report = [[DOCoreDiagnostics environmentReport] mutableCopy];
    report[@"resources_complete"] = @([self resourceError] == nil);
    report[@"version_comparison_available"] = @([NSString instancesRespondToSelector:NSSelectorFromString(@"numericalVersionRepresentation")]);
    report[@"ui_version"] = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    report[@"runtime_version"] = self.applicationVersion;
    report[@"supported"] = @([DOEnvironmentManager sharedManager].isSupported);
    report[@"environment_active"] = @([DOEnvironmentManager sharedManager].isJailbroken || [DOEnvironmentManager sharedManager].isJailbrokenWithOtherJailbreak);
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
    [self log:[@"[LAOHEMA_DIAGNOSTICS] " stringByAppendingString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]] debug:YES update:NO];
}
@end
