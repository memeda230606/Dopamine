#import "DOCommandLineCoreHost.h"
#import "DOPreferenceManager.h"
@implementation DOCommandLineCoreHost
+ (void)install { [DOPreferenceManager sharedManager]; [DOCoreContext installHost:[self new]]; }
- (NSDictionary *)settingsSnapshot { return [[DOPreferenceManager sharedManager] settingsSnapshot]; }
- (void)setSetting:(id)value forKey:(NSString *)key { [[DOPreferenceManager sharedManager] setPreferenceValue:value forKey:key]; }
- (NSString *)resourceDirectory { return NSBundle.mainBundle.bundlePath; }
- (NSString *)documentsDirectory { return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]; }
- (NSString *)applicationIdentifier { return @""; }
- (NSString *)applicationVersion { return @"standalone"; }
- (NSString *)applicationBuild { return @"standalone"; }
- (NSArray *)packageManagers { return @[]; }
- (NSData *)bootLogoData { return nil; }
- (NSString *)localizedString:(NSString *)key { return key; }
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update { printf("%s%s\n", debug ? "[d] " : "", message.UTF8String); }
- (BOOL)allowsUserspaceReboot { return NO; }
@end
