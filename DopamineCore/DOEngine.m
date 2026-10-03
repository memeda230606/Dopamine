#import "DOEngine.h"
#import "DOCoreDiagnostics.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"
@interface DOEngine ()
@property(nonatomic, strong) DOJailbreaker *implementation;
@end
@implementation DOEngine
+ (BOOL)isActive { return self.isOwnedEnvironment || DOEnvironmentManager.sharedManager.isJailbrokenWithOtherJailbreak; }
+ (BOOL)isOwnedEnvironment { return DOEnvironmentManager.sharedManager.isJailbroken; }
+ (BOOL)isSupported { return DOEnvironmentManager.sharedManager.isSupported; }
+ (BOOL)isBootstrapped { return DOEnvironmentManager.sharedManager.isBootstrapped; }
+ (BOOL)isTweakInjectionEnabled { return DOEnvironmentManager.sharedManager.isTweakInjectionEnabled; }
+ (NSDictionary *)diagnostics {
    NSMutableDictionary *report=[[DOCoreDiagnostics environmentReport] mutableCopy];
    DOCoreContext *context=DOCoreContext.sharedContext;
    NSDictionary *manifest=[NSDictionary dictionaryWithContentsOfFile:[context resourcePath:@"RuntimeManifest.plist"]];
    NSMutableArray *missing=[NSMutableArray array];
    NSArray *required=manifest[@"required_files"];
    for(NSString *name in required) {
        if(![NSFileManager.defaultManager fileExistsAtPath:[context resourcePath:name]])[missing addObject:name];
    }
    BOOL category=[@"1.0" respondsToSelector:NSSelectorFromString(@"numericalVersionRepresentation")];
    report[@"resources_complete"]=@(required.count>0 && !missing.count && category);
    report[@"missing_resources"]=missing;
    report[@"version_comparison_available"]=@(category);
    report[@"environment_active"]=@(self.isActive);
    report[@"supported"]=@(self.isSupported);
    return report;
}
- (instancetype)init { if ((self = [super init])) _implementation = [DOJailbreaker new]; return self; }
- (BOOL)contiguousMappingWorkaroundNeeded { return [self.implementation contiguousMappingWorkaroundNeeded]; }
- (void)applyContiguousMappingWorkaround { [self.implementation applyContiguousMappingWorkaround]; }
- (DOResult *)run { return [self.implementation run]; }
- (void)finalize { [self.implementation finalize]; }
@end
