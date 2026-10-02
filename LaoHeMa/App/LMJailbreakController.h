#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, LMState) {
    LMStateReady, LMStateRunning, LMStateJailbroken, LMStateUnsupported,
    LMStateFailed, LMStateNeedsWorkaround, LMStateFinishing
};
@protocol LMJailbreakControlling <NSObject>
@property(nonatomic, readonly) LMState state;
@property(nonatomic, copy, readonly) NSString *message;
@property(nonatomic, copy, nullable) void (^onChange)(void);
- (void)start;
- (void)applyWorkaround;
- (void)cancelWorkaround;
@end
@class LMCoreHost;
@interface LMJailbreakController : NSObject <LMJailbreakControlling>
@property(nonatomic, copy, nullable) void (^onChange)(void);
- (instancetype)initWithHost:(LMCoreHost *)host;
@end
NS_ASSUME_NONNULL_END
