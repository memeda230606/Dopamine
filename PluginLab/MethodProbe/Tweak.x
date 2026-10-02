#import <Foundation/Foundation.h>

@interface PLProbe : NSObject
- (NSInteger)calculate:(NSInteger)value;
@end

%group LabOnly
%hook PLProbe
- (NSInteger)calculate:(NSInteger)value {
    NSInteger original = %orig;
    return original + 7;
}
%end
%end

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.mmd.PluginLab"]) %init(LabOnly);
}
