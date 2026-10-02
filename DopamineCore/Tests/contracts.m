#import "DOCore.h"
@interface TestHost : NSObject <DOCoreHost>
@property NSMutableDictionary *settings;
@property NSMutableArray *logs;
@end
@implementation TestHost
- (NSDictionary *)settingsSnapshot { return self.settings; }
- (void)setSetting:(id)value forKey:(NSString *)key { self.settings[key] = value; }
- (NSString *)resourceDirectory { return @"/test/resources"; }
- (NSString *)documentsDirectory { return @"/test/documents"; }
- (NSString *)applicationIdentifier { return @"test.core"; }
- (NSString *)applicationVersion { return @"1"; }
- (NSString *)applicationBuild { return @"1"; }
- (NSArray *)packageManagers { return @[]; }
- (NSData *)bootLogoData { return nil; }
- (NSString *)localizedString:(NSString *)key { return [@"translated:" stringByAppendingString:key]; }
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update { [self.logs addObject:@{@"text":message,@"debug":@(debug),@"update":@(update)}]; }
- (BOOL)allowsUserspaceReboot { return NO; }
@end
#define CHECK(test) do { if (!(test)) { fprintf(stderr,"Failed: %s\n", #test); return 1; } } while (0)
int main(void) {
    @autoreleasepool {
        BOOL missing = NO;
        @try { [DOCoreContext sharedContext]; } @catch(NSException *e) { missing = YES; }
        CHECK(missing);
        TestHost *host = [TestHost new];
        host.settings = [@{@"enabled":@YES, @"nested":[NSMutableArray arrayWithObject:@"before"]} mutableCopy];
        host.logs = [NSMutableArray new];
        [DOCoreContext installHost:host];
        DOCoreContext *context = [DOCoreContext sharedContext];
        CHECK([context beginOperation]);
        CHECK(![context beginOperation]);
        [host.settings[@"nested"] addObject:@"after"];
        [context setPreferenceValue:@NO forKey:@"enabled"];
        CHECK([context boolPreferenceValueForKey:@"enabled" fallback:NO]);
        CHECK([[context preferenceValueForKey:@"nested"] count] == 1);
        CHECK([context boolPreferenceValueForKey:@"missing" fallback:YES]);
        [context sendLog:@"progress" debug:YES update:YES];
        CHECK(([host.logs.lastObject isEqual:@{@"text":@"progress",@"debug":@YES,@"update":@YES}]));
        CHECK([DOTranslate(@"phase") isEqual:@"translated:phase"]);
        CHECK([[context resourcePath:@"Frameworks/probe"] isEqual:@"/test/resources/Frameworks/probe"]);
        for (NSString *path in @[@"../escape", @"/absolute"]) {
            BOOL rejected = NO;
            @try { [context resourcePath:path]; } @catch(NSException *e) { rejected = YES; }
            CHECK(rejected);
        }
        [context endOperation];
        CHECK(![context boolPreferenceValueForKey:@"enabled" fallback:YES]);
        CHECK([context beginOperation]);
        CHECK([[context preferenceValueForKey:@"nested"] count] == 2);
        [context endOperation];
        NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
        DOResult *failed = [[DOResult alloc] initWithError:error removed:NO showLogs:YES action:DOCompletionActionUserspaceReboot];
        DOResult *removed = [[DOResult alloc] initWithError:nil removed:YES showLogs:NO action:DOCompletionActionUserspaceReboot];
        DOResult *success = [[DOResult alloc] initWithError:nil removed:NO showLogs:YES action:DOCompletionActionUserspaceReboot];
        CHECK(failed.completionAction == DOCompletionActionNone && failed.error == error);
        CHECK(removed.completionAction == DOCompletionActionNone && removed.didRemoveJailbreak);
        CHECK(success.completionAction == DOCompletionActionUserspaceReboot);
        BOOL replaced = NO;
        @try { [DOCoreContext installHost:host]; } @catch(NSException *e) { replaced = YES; }
        CHECK(replaced);
        puts("{\"passed\":true,\"checks\":[\"explicit-host\",\"single-operation\",\"immutable-deep-snapshot\",\"write-through-settings\",\"resource-boundary\",\"event-adapter\",\"completion-policy\"]}");
    }
    return 0;
}
