#import "AppDelegate.h"
#import <AudioToolbox/AudioToolbox.h>
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
    label.text = @"BEAT//4\n\nAUv3 INSTRUMENT\n\nOpen AUM > Audio Channel\n> Audio Unit Instrument > BEAT//4\n\nCircuit Tracks PC on MIDI channel 16.\nAUM Control output → AUM MIDI Control.\nCircuit Projects output → Circuit Tracks.\nThis display runs inside AUM.";
    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BEAT4Logo"]];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.isAccessibilityElement = YES;
    logo.accessibilityLabel = @"BEAT quatre temps";
    AudioComponentDescription description = {
        .componentType = kAudioUnitType_MusicDevice,
        .componentSubType = 'bt04',
        .componentManufacturer = 'B4MT',
    };
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    UIImage *componentIcon = component ? AudioComponentCopyIcon(component) : nil;
    UIImageView *systemLogo = [[UIImageView alloc] initWithImage:componentIcon];
    systemLogo.contentMode = UIViewContentModeScaleAspectFit;
    systemLogo.isAccessibilityElement = YES;
    systemLogo.accessibilityLabel = @"Icône AUv3 fournie par iPadOS";
    [NSLayoutConstraint activateConstraints:@[
        [systemLogo.widthAnchor constraintEqualToConstant:72],
        [systemLogo.heightAnchor constraintEqualToConstant:72]
    ]];
    UIStackView *icons = [[UIStackView alloc] initWithArrangedSubviews:@[logo, systemLogo]];
    icons.alignment = UIStackViewAlignmentCenter;
    icons.spacing = 24;
    if (!component) {
        label.text = @"Diagnostic du logo BEAT//4\n\niPadOS ne trouve pas le composant AUv3.";
    } else if (!componentIcon) {
        label.text = @"Diagnostic du logo BEAT//4\n\nLe composant AUv3 est présent.\niPadOS ne fournit aucune icône.";
    } else {
        label.text = @"Diagnostic du logo BEAT//4\n\nÀ gauche : logo du projet.\nÀ droite : icône AUv3 fournie par iPadOS.";
    }
    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[icons, label]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentCenter;
    content.spacing = 16;
    [controller.view addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [content.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [content.widthAnchor constraintLessThanOrEqualToAnchor:controller.view.widthAnchor multiplier:.9], [logo.widthAnchor constraintEqualToConstant:96], [logo.heightAnchor constraintEqualToConstant:96]
    ]];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
