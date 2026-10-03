#import "LMViewController.h"
@interface LMViewController ()
@property(nonatomic, strong) id<LMJailbreakControlling> controller;
@property(nonatomic, strong) UIButton *button;
@property(nonatomic, strong) UILabel *statusLabel;
@end
@implementation LMViewController
- (instancetype)initWithController:(id<LMJailbreakControlling>)controller {
    if ((self = [super init])) _controller = controller;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.button = [UIButton buttonWithType:UIButtonTypeSystem];
    self.button.accessibilityIdentifier = @"jailbreak";
    self.button.translatesAutoresizingMaskIntoConstraints = NO;
    self.button.configuration = [UIButtonConfiguration filledButtonConfiguration];
    [self.button addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.button];
    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.adjustsFontForContentSizeCategory = YES;
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.accessibilityIdentifier = @"status";
    [self.view addSubview:self.statusLabel];
    NSLayoutConstraint *width = [self.button.widthAnchor constraintEqualToConstant:280];
    width.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.button.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [self.button.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor constant:-24],
        width,
        [self.button.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:28],
        [self.button.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-28],
        [self.button.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.button.bottomAnchor constant:20],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.button.centerXAnchor],
        [self.statusLabel.widthAnchor constraintLessThanOrEqualToConstant:460],
        [self.statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:28],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-28],
        [self.statusLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
    __weak typeof(self) weakSelf = self;
    self.controller.onChange = ^{ [weakSelf render]; };
    [self render];
}
- (void)start { [self.controller start]; }
- (void)render {
    LMState state = self.controller.state;
    BOOL running = state == LMStateRunning || state == LMStateFinishing;
    NSArray *titles = @[@"测试", @"测试中", @"ok", @"暂不支持", @"请重新打开", @"准备环境", @"正在完成"];
    UIButtonConfiguration *config = self.button.configuration;
    config.title = titles[state];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = [UIColor colorWithRed:0.13 green:0.35 blue:0.32 alpha:1];
    config.contentInsets = NSDirectionalEdgeInsetsMake(18, 26, 18, 26);
    config.showsActivityIndicator = running;
    self.button.configuration = config;
    self.button.enabled = state == LMStateReady;
    self.statusLabel.text = self.controller.message;
    UIApplication.sharedApplication.idleTimerDisabled = running;
    if (state == LMStateNeedsWorkaround && !self.presentedViewController) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"准备环境" message:self.controller.message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { [self.controller cancelWorkaround]; }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self.controller applyWorkaround]; }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
@end
