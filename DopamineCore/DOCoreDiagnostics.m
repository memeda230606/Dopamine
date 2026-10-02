#import "DOCoreDiagnostics.h"
#import "DOCore.h"
#import "DOEnvironmentManager.h"
#import "DOExploitManager.h"
#import "DOExploit.h"
#import <sys/sysctl.h>
@implementation DOCoreDiagnostics
+ (NSDictionary *)environmentReport {
    DOCoreContext *context = [DOCoreContext sharedContext];
    DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
    DOExploitManager *exploits = [DOExploitManager sharedManager];
    NSMutableDictionary *resources = [NSMutableDictionary dictionary];
    for (NSString *name in @[@"Frameworks", @"basebin.tar", @"bootstrap_1900.tar.zst"]) {
        resources[name] = @([NSFileManager.defaultManager fileExistsAtPath:[context resourcePath:name]]);
    }
    char uuid[128] = {0}; size_t size = sizeof(uuid);
    BOOL bootAvailable = sysctlbyname("kern.bootsessionuuid", uuid, &size, NULL, 0) == 0;
    return @{@"core_api_version":@1, @"build":context.host.applicationBuild,
        @"application":context.host.applicationIdentifier, @"system_version":environment.systemVersion,
        @"jailbreak_active":@(environment.isJailbroken), @"resources":resources,
        @"selected_kernel_exploit":exploits.selectedKernelExploit.identifier ?: @"",
        @"selected_ppl_bypass":exploits.selectedPPLBypass.identifier ?: @"",
        @"allows_userspace_reboot":@([context.host allowsUserspaceReboot]),
        @"boot_uuid":bootAvailable ? @(uuid) : @"", @"read_only":@YES};
}
@end
