#import "DOCommandLine.h"
#import "DOEngine.h"
static void Emit(NSDictionary *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [[DOCoreContext sharedContext] sendLog:[@"[CORE_CLI] " stringByAppendingString:text] debug:NO];
    puts(text.UTF8String);
}
BOOL DOHandleCommandLine(int argc, const char *const argv[], int *exitCode) {
    if (argc < 2 || strncmp(argv[1], "--core-", 7)) return NO;
    *exitCode = 0;
    NSString *command = @(argv[1]);
    if ([command isEqual:@"--core-status"]) { Emit(DOEngine.diagnostics); return YES; }
    if (![command isEqual:@"--core-run"] && ![command isEqual:@"--core-prepare"]) {
        Emit(@{@"error":@"Unknown command", @"commands":@[@"--core-status", @"--core-run", @"--core-prepare"]}); *exitCode=64; return YES;
    }
    if (DOEngine.isActive) { Emit(@{@"status":@"already_active", @"executed":@NO}); return YES; }
    if (!DOEngine.isSupported) { Emit(@{@"status":@"unsupported", @"executed":@NO}); *exitCode=69; return YES; }
    NSDictionary *diagnostics=DOEngine.diagnostics;
    if(![diagnostics[@"resources_complete"] boolValue]) { Emit(@{@"status":@"missing_resources",@"executed":@NO});*exitCode=66;return YES; }
    DOEngine *engine = [DOEngine new];
    if ([engine contiguousMappingWorkaroundNeeded]) {
        if ([command isEqual:@"--core-prepare"]) [engine applyContiguousMappingWorkaround];
        Emit(@{@"status":@"preparation_required", @"executed":@NO}); *exitCode=75; return YES;
    }
    if ([command isEqual:@"--core-prepare"]) { Emit(@{@"status":@"preparation_not_required"}); return YES; }
    DOResult *result = [engine run];
    Emit(@{@"status":result.error ? @"failed" : @"completed", @"error":result.error.localizedDescription ?: @"", @"completion_action":@(result.completionAction)});
    if (result.error) *exitCode=1;
    else [engine finalize];
    return YES;
}
