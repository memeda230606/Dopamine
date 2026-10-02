#import <UIKit/UIKit.h>

@interface PLViewController : UIViewController
@property (nonatomic, strong) UILabel *pluginBadge;
- (void)renderPluginSlot;
@end

%group LabOnly
%hook PLViewController
- (void)renderPluginSlot {
    %orig;
    self.pluginBadge.text = @"独立 UI 插件已加载";
    self.pluginBadge.textColor = UIColor.systemGreenColor;
    self.pluginBadge.accessibilityIdentifier = @"PluginLab.UIProbe.Active";
}
%end
%end

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.mmd.PluginLab"]) %init(LabOnly);
}
