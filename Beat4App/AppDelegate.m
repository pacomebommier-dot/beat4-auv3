#import "AppDelegate.h"
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    (void)app; (void)opts;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor colorWithRed:.028 green:.035 blue:.030 alpha:1];
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textColor = [UIColor colorWithRed:.76 green:.86 blue:.70 alpha:1];
    label.font = [UIFont monospacedSystemFontOfSize:19 weight:UIFontWeightSemibold];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"BEAT//4\n\nAUv3 INSTRUMENT\n\nOpen AUM > Audio Channel\n> Audio Unit Instrument > BEAT//4\n\nCircuit Tracks PG on MIDI channel 16.\nRoute BEAT//4 MIDI OUT to AUM MIDI Control.\nThis display runs inside AUM.";
    [controller.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [label.widthAnchor constraintLessThanOrEqualToAnchor:controller.view.widthAnchor multiplier:.9]
    ]];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
