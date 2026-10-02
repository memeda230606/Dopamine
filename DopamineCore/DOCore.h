#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

// Implemented by the entry point. The core never imports its UI or preferences.
@protocol DOCoreHost <NSObject>
- (NSDictionary<NSString *, id> *)settingsSnapshot;
- (void)setSetting:(id)value forKey:(NSString *)key;
- (NSString *)resourceDirectory;
- (NSString *)documentsDirectory;
- (NSString *)applicationIdentifier;
- (NSString *)applicationVersion;
- (NSString *)applicationBuild;
- (NSArray<NSDictionary *> *)packageManagers;
- (nullable NSData *)bootLogoData;
- (NSString *)localizedString:(NSString *)key;
- (void)log:(NSString *)message debug:(BOOL)debug update:(BOOL)update;
- (BOOL)allowsUserspaceReboot;
@end

@interface DOConfiguration : NSObject
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *values;
- (instancetype)initWithValues:(NSDictionary<NSString *, id> *)values;
- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback;
@end

typedef NS_ENUM(NSInteger, DOCompletionAction) {
    DOCompletionActionNone,
    DOCompletionActionUserspaceReboot,
};
@interface DOResult : NSObject
@property(nonatomic, readonly, nullable) NSError *error;
@property(nonatomic, readonly) BOOL didRemoveJailbreak;
@property(nonatomic, readonly) BOOL showLogs;
@property(nonatomic, readonly) DOCompletionAction completionAction;
- (instancetype)initWithError:(nullable NSError *)error removed:(BOOL)removed showLogs:(BOOL)showLogs action:(DOCompletionAction)action;
@end

// The upstream primitives and managers have process-global state. Install once
// before creating any manager; one operation may be active per process.
@interface DOCoreContext : NSObject
@property(nonatomic, strong, readonly) id<DOCoreHost> host;
@property(atomic, strong, readonly, nullable) DOConfiguration *configuration;
+ (void)installHost:(id<DOCoreHost>)host;
+ (instancetype)sharedContext;
- (BOOL)beginOperation;
- (void)endOperation;
- (nullable id)preferenceValueForKey:(NSString *)key;
- (BOOL)boolPreferenceValueForKey:(NSString *)key fallback:(BOOL)fallback;
- (void)setPreferenceValue:(id)value forKey:(NSString *)key;
- (NSString *)resourcePath:(NSString *)relativePath;
- (void)sendLog:(NSString *)message debug:(BOOL)debug;
- (void)sendLog:(NSString *)message debug:(BOOL)debug update:(BOOL)update;
@end
FOUNDATION_EXPORT NSString *DOTranslate(NSString *key);
NS_ASSUME_NONNULL_END
