#import "DOCommandLineCoreHost.h"
@interface DOCommandLineCoreHost ()
@property(nonatomic, copy) NSString *preferencesPath;
@property(nonatomic, strong) NSMutableDictionary *preferences;
@end
@implementation DOCommandLineCoreHost
+ (void)install {
    DOCommandLineCoreHost *host=[self new];
    host.preferencesPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.opa334.Dopamine.plist"];
    host.preferences=[[NSDictionary dictionaryWithContentsOfFile:host.preferencesPath] mutableCopy] ?: [NSMutableDictionary new];
    [DOCoreContext installHost:host];
}
- (NSDictionary *)settingsSnapshot { return self.preferences.copy; }
- (void)setSetting:(id)value forKey:(NSString *)key { self.preferences[key]=value;[self.preferences writeToFile:self.preferencesPath atomically:YES]; }
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
