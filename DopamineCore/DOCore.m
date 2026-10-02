#import "DOCore.h"

@implementation DOConfiguration
- (instancetype)initWithValues:(NSDictionary<NSString *,id> *)values {
    if ((self = [super init])) {
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:values format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
        if (!data) [NSException raise:NSInvalidArgumentException format:@"Core settings must be a property list: %@", error];
        _values = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
        if (!_values) [NSException raise:NSInvalidArgumentException format:@"Invalid settings: %@", error];
    }
    return self;
}
- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = self.values[key];
    return value ? [value boolValue] : fallback;
}
@end

@implementation DOResult
- (instancetype)initWithError:(NSError *)error removed:(BOOL)removed showLogs:(BOOL)showLogs action:(DOCompletionAction)action {
    if ((self = [super init])) {
        _error = error; _didRemoveJailbreak = removed; _showLogs = showLogs;
        _completionAction = (error || removed) ? DOCompletionActionNone : action;
    }
    return self;
}
@end

@interface DOCoreContext ()
@property(nonatomic, strong, readwrite) id<DOCoreHost> host;
@property(atomic, strong, readwrite) DOConfiguration *configuration;
@property(nonatomic, strong) NSLock *operationLock;
@end
static DOCoreContext *context;
@implementation DOCoreContext
+ (void)installHost:(id<DOCoreHost>)host {
    @synchronized(self) {
        if (context) [NSException raise:NSInternalInconsistencyException format:@"Core host is already installed"];
        if (!host) [NSException raise:NSInvalidArgumentException format:@"A core host is required"];
        context = [self new]; context.host = host; context.operationLock = [NSLock new];
    }
}
+ (instancetype)sharedContext {
    @synchronized(self) {
        if (!context) [NSException raise:NSInternalInconsistencyException format:@"Install DOCoreHost before using DopamineCore"];
        return context;
    }
}
- (BOOL)beginOperation {
    if (![self.operationLock tryLock]) return NO;
    @try { self.configuration = [[DOConfiguration alloc] initWithValues:[self.host settingsSnapshot]]; }
    @catch (NSException *exception) { [self.operationLock unlock]; @throw; }
    return YES;
}
- (void)endOperation { self.configuration = nil; [self.operationLock unlock]; }
- (id)preferenceValueForKey:(NSString *)key {
    DOConfiguration *configuration = self.configuration;
    return configuration ? configuration.values[key] : [self.host settingsSnapshot][key];
}
- (BOOL)boolPreferenceValueForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = [self preferenceValueForKey:key]; return value ? [value boolValue] : fallback;
}
- (void)setPreferenceValue:(id)value forKey:(NSString *)key { [self.host setSetting:value forKey:key]; }
- (NSString *)resourcePath:(NSString *)relativePath {
    NSString *root = self.host.resourceDirectory.stringByStandardizingPath;
    NSString *path = [root stringByAppendingPathComponent:relativePath].stringByStandardizingPath;
    if (relativePath.isAbsolutePath || ![path hasPrefix:[root stringByAppendingString:@"/"]])
        [NSException raise:NSInvalidArgumentException format:@"Resource must be within the supplied directory"];
    return path;
}
- (void)sendLog:(NSString *)message debug:(BOOL)debug { [self sendLog:message debug:debug update:NO]; }
- (void)sendLog:(NSString *)message debug:(BOOL)debug update:(BOOL)update { [self.host log:message debug:debug update:update]; }
@end
NSString *DOTranslate(NSString *key) { return [[DOCoreContext sharedContext].host localizedString:key]; }
