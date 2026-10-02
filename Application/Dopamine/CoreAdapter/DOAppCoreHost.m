#import "DOAppCoreHost.h"
#import "DOPreferenceManager.h"
#import "DOUIManager.h"
#import "UIImage+JPEG2000.h"

@interface DOAppCoreHost ()
@property(nonatomic, copy) NSString *documents;
@end
@implementation DOAppCoreHost
+ (void)install {
    DOAppCoreHost *host = [self new];
    // Resolve before the jailbreak changes HOME / process credentials.
    host.documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    [DOPreferenceManager sharedManager];
    [DOCoreContext installHost:host];
}
- (NSDictionary *)settingsSnapshot { return [[DOPreferenceManager sharedManager] settingsSnapshot]; }
- (void)setSetting:(id)value forKey:(NSString *)key { [[DOPreferenceManager sharedManager] setPreferenceValue:value forKey:key]; }
- (NSString *)resourceDirectory { return NSBundle.mainBundle.bundlePath; }
- (NSString *)documentsDirectory { return self.documents; }
- (NSString *)applicationIdentifier { return NSBundle.mainBundle.bundleIdentifier ?: @""; }
- (NSString *)applicationVersion { return NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @""; }
- (NSString *)applicationBuild { return NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @""; }
- (NSArray *)packageManagers {
    NSArray *keys = [[DOCoreContext sharedContext] preferenceValueForKey:@"enabledPkgManagers"] ?: @[];
    NSPredicate *selected = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return [keys containsObject:item[@"Key"]];
    }];
    return [[[DOUIManager sharedInstance] availablePackageManagers] filteredArrayUsingPredicate:selected];
}
- (NSString *)localizedString:(NSString *)key { return DOLocalizedString(key); }
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update { [[DOUIManager sharedInstance] sendLog:message debug:debug update:update]; }
- (BOOL)allowsUserspaceReboot {
#if DOPAMINE_NO_REBOOT_TEST
    return NO;
#else
    return YES;
#endif
}
- (NSData *)bootLogoData {
    __block NSData *data;
    void (^render)(void) = ^{
        UIImage *image = nil;
        if ([[DOCoreContext sharedContext] boolPreferenceValueForKey:@"customBootlogoEnabled" fallback:NO])
            image = [UIImage imageWithContentsOfFile:[DOUIManager sharedInstance].bootlogoPath];
        if (!image) image = [[DOUIManager sharedInstance] renderBootLogo];
        data = [image jp2DataWithCompressionQuality:0.9];
    };
    if (NSThread.isMainThread) render(); else dispatch_sync(dispatch_get_main_queue(), render);
    return data;
}
+ (NSString *)summaryForNoRebootReport:(NSDictionary *)report {
    NSDictionary *after = report[@"after"], *checks = report[@"checks"];
    return [NSString stringWithFormat:@"已跳过用户空间重启。\n\n越狱服务：%@\n内核读取：%@\n新进程 root 命令：%@\n系统与桌面均未重启：%@\n\n本次仅检查核心能力，尚未验证全部插件与后台服务。诊断日志已记录。",
        [after[@"jbserver_responds"] boolValue] ? @"通过" : @"未通过",
        [after[@"kernel_read_verified"] boolValue] ? @"通过" : @"未通过",
        [checks[@"root_command"] boolValue] ? @"通过" : @"未通过",
        [checks[@"same_kernel_boot"] boolValue] && [checks[@"same_springboard"] boolValue] ? @"已确认" : @"待核实"];
}
@end
