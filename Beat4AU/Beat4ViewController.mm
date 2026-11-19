#import "Beat4ViewController.h"
#import "Beat4AudioUnit.h"
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <cmath>
#include <algorithm>
#include "Beat4Kick.hpp"
#include "Beat4Songs.hpp"
#include "Beat4Layout.hpp"
#include "Beat4Display.hpp"
#include "Beat4Lights.hpp"
#include "Beat4Transport.hpp"
#include "Beat4BPMGesture.hpp"
#include "Beat4Set.hpp"
#include "Beat4Store.h"
#include "Beat4Config.h"

static UIColor *RGB(CGFloat r,CGFloat g,CGFloat b,CGFloat a=1){
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}
static UIFont *Mono(CGFloat sz,UIFontWeight w=UIFontWeightRegular){
    return [UIFont monospacedSystemFontOfSize:sz weight:w];
}
static NSInteger circuitColorIndex(NSInteger pc,NSString *overrideColor) {
    if(overrideColor.length){
        NSUInteger index=[beat4::rampPaletteNames() indexOfObject:overrideColor];
        if(index!=NSNotFound)return (NSInteger)index;
    }
    switch(pc+1){
    case 1:case 9:case 10:case 17:case 25:case 33:case 41:case 42:case 49:return 0;
    case 6:case 27:case 31:return 1;
    case 7:case 8:case 56:case 63:case 64:return 2;
    case 16:case 18:case 26:return 3;
    case 32:case 57:return 4;
    case 40:return 5;
    case 50:return 6;
    case 11:return 7;
    default:return -1;
    }
}
static UIColor *circuitColor(NSInteger index){
    static const int colors[][3]={{198,56,48},{195,162,34},{60,145,78},{187,75,128},
        {65,106,197},{244,137,128},{100,242,135},{232,137,42}};
    return RGB(colors[index][0],colors[index][1],colors[index][2]);
}
@interface Beat4Button : UIButton @end
@implementation Beat4Button
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    (void)event;const CGFloat dx=MAX(0,(44-self.bounds.size.width)*.5);
    const CGFloat dy=MAX(0,(44-self.bounds.size.height)*.5);
    return CGRectContainsPoint(CGRectInset(self.bounds,-dx,-dy),point);
}
@end
// Mini-pad width is also its exclusive horizontal hit zone. Only expand
// vertically: neighboring mini-pads and title must never steal each other's taps.
@interface Beat4TitleLabel : UILabel @end
@implementation Beat4TitleLabel
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    (void)event;
    return CGRectContainsPoint(CGRectInset(self.bounds,0,-MAX(0,(44-self.bounds.size.height)/2)),point);
}
@end
@interface Beat4MiniButton : UIButton @end
@implementation Beat4MiniButton
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    (void)event;return CGRectContainsPoint(CGRectInset(self.bounds,0,-7),point);
}
@end
@interface Beat4Canvas : UIView {
    beat4::Lights _lights;
    CFTimeInterval _lightTick;
}
@property(nonatomic,copy)NSDictionary<NSString*,NSNumber*> *snapshot;
@property(nonatomic,assign)CGRect lightBounds,beatSquareBounds;
@property(nonatomic,assign)BOOL showBars;
- (BOOL)lightsAnimating;
@end
@implementation Beat4Canvas
- (BOOL)lightsAnimating {return _lights.animating();}
- (void)setSnapshot:(NSDictionary<NSString*,NSNumber*>*)snapshot {
    const CFTimeInterval now=CACurrentMediaTime();
    const double dt=_lightTick>0?now-_lightTick:0;_lightTick=now;
    const bool stop=[snapshot[@"localStop"] boolValue] ||
        [snapshot[@"mode"] intValue]==static_cast<int>(beat4::HostMode::Rewound);
    _lights.update([snapshot[@"displayBeat"] doubleValue],[snapshot[@"moving"] boolValue],
        [snapshot[@"synced"] boolValue],stop,dt,[snapshot[@"bpm"] doubleValue]);
    _snapshot=[snapshot copy];[self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    [RGB(7,9,8) setFill];UIRectFill(rect);
    const auto layout=beat4::layoutFor(self.bounds.size.width,self.bounds.size.height);
    CGContextRef ctx=UIGraphicsGetCurrentContext();if(!ctx)return;
    for(int i=0;i<4;++i){
        const CGFloat energy=_lights.energy(i);
        const CGFloat square=self.beatSquareBounds.size.height;
        const CGRect r=self.showBars?CGRectMake(self.lightBounds.origin.x+i*(layout.barWidth+layout.barGap),
            self.lightBounds.origin.y,layout.barWidth,self.lightBounds.size.height):
            CGRectMake(self.beatSquareBounds.origin.x+i*(square+4),self.beatSquareBounds.origin.y,square,square);
        UIBezierPath *shape=[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:self.showBars?layout.corner:2];
        CGContextSaveGState(ctx);
        if(energy>.001)CGContextSetShadowWithColor(ctx,CGSizeZero,16*layout.scale,
            RGB(151,185,139,.35*energy).CGColor);
        [RGB(24,34,26) setFill];[shape fill];CGContextRestoreGState(ctx);
        if(energy>.001){
            // V2/R02 vertical phosphor gradient; energy comes exclusively from host-beat envelope.
            const CGFloat colors[]={217./255,239./255,199./255,energy, 187./255,216./255,173./255,energy, 130./255,158./255,121./255,energy};
            const CGFloat stops[]={0,.5,1};CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient=CGGradientCreateWithColorComponents(space,colors,stops,3);
            CGContextSaveGState(ctx);[shape addClip];
            CGContextDrawLinearGradient(ctx,gradient,CGPointMake(CGRectGetMidX(r),CGRectGetMinY(r)),
                CGPointMake(CGRectGetMidX(r),CGRectGetMaxY(r)),0);
            CGContextRestoreGState(ctx);CGGradientRelease(gradient);CGColorSpaceRelease(space);
        }
        [RGB(43+148*energy,60+155*energy,45+134*energy) setStroke];
        shape.lineWidth=MAX(.6,layout.scale);[shape stroke];
    }
}
@end

@interface Beat4ViewController () <UIDocumentPickerDelegate>
@property(nonatomic,strong)Beat4AudioUnit *unit;
@property(nonatomic,strong)Beat4Canvas *canvas;
@property(nonatomic,strong)CADisplayLink *clock;
@property(nonatomic,copy)NSDictionary *frameSnapshot;
@property(nonatomic,strong)UILabel *logo,*versionLabel,*host,*pgLabel,*subLabel,*levelLabel,*modeLabel,*pcModeLabel;
@property(nonatomic,strong)UIButton *kickButton,*noteButton,*songButton,*bpmButton;
@property(nonatomic,strong)UIButton *playButton,*queueButton,*saveButton;
@property(nonatomic,strong)UISegmentedControl *modeControl;
@property(nonatomic,strong)UIButton *setButton,*setEditButton,*rampToggle,*rampDuration;
@property(nonatomic,strong)UILabel *hostBPM;
@property(nonatomic,assign)NSInteger shownRampProgram,shownRampBars;
@property(nonatomic,strong)NSMutableArray<UIButton*> *setPads;
@property(nonatomic,assign)BOOL setEditing;
@property(nonatomic,assign)NSInteger setEditPosition;
@property(nonatomic,assign)CFTimeInterval playPressTime;
@property(nonatomic,strong)UIView *pageRegion;
@property(nonatomic,strong)NSMutableArray<UIButton*> *pads;
@property(nonatomic,assign)NSInteger page,editedPC;
@property(nonatomic,strong)UISlider *levelSlider;
@property(nonatomic,assign)NSInteger seenPG;
@property(nonatomic,assign)double bpmDragStart;
@property(nonatomic,assign)CGFloat bpmDragOriginX;
@property(nonatomic,assign)NSInteger bpmDragProgram;
@property(nonatomic,assign)BOOL bpmDragging;
@property(nonatomic,assign)uint64_t seenRevision;
@property(nonatomic,assign)CFTimeInterval lastWatchdog;
@property(nonatomic,assign)BOOL lastMoving,lastSynced;
@end
@implementation Beat4ViewController
- (AUAudioUnit *)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc
                                                  error:(NSError * _Nullable __autoreleasing *)error {
    self.unit=[[Beat4AudioUnit alloc]initWithComponentDescription:desc options:0 error:error];
    return self.unit;
}
- (UILabel *)makeLabel:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *v=[UILabel new];v.text=text;v.textColor=color;v.font=Mono(size);v.backgroundColor=UIColor.clearColor;
    v.adjustsFontSizeToFitWidth=YES;v.minimumScaleFactor=.66;[self.view addSubview:v];return v;
}
- (UIButton *)makeButton:(NSString *)text size:(CGFloat)size {
    UIButton *b=[Beat4Button buttonWithType:UIButtonTypeCustom];
    [b setTitle:text forState:UIControlStateNormal];[b setTitleColor:RGB(219,223,209) forState:UIControlStateNormal];
    b.titleLabel.font=Mono(size,UIFontWeightMedium);
    b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    [self.view addSubview:b];return b;
}
- (void)loadView {
    Beat4Canvas *canvas=[[Beat4Canvas alloc]initWithFrame:CGRectMake(0,0,720,400)];
    canvas.backgroundColor=RGB(7,9,8);self.canvas=canvas;self.view=canvas;
    self.preferredContentSize=CGSizeMake(720,400);
    self.setEditPosition=-1;self.seenPG=-999;self.editedPC=0;self.canvas.showBars=YES;
    _logo=[self makeLabel:@"BEAT//4" size:20 color:RGB(228,230,219)];
    _logo.font=Mono(20,UIFontWeightSemibold);
    _logo.userInteractionEnabled=YES;
    _logo.accessibilityLabel=@"BEAT//4, menu SONGS et SET";
    _logo.accessibilityTraits=UIAccessibilityTraitButton;
    [_logo addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(showConfigurationMenu:)]];
    _versionLabel=[self makeLabel:[NSString stringWithFormat:@"v%@",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.5.18"] size:8 color:RGB(122,145,121)];
    _modeLabel=[self makeLabel:@"QUEUE" size:10 color:RGB(197,208,197)];
    _hostBPM=[self makeLabel:@"" size:12 color:RGB(145,148,145)];
    _host=[[Beat4TitleLabel alloc]init];_host.text=@"MÉTRONOME";
    _host.font=Mono(11);_host.textColor=RGB(144,161,140);[self.view addSubview:_host];
    _host.textAlignment=NSTextAlignmentLeft;
    _host.userInteractionEnabled=YES;_host.accessibilityTraits=UIAccessibilityTraitButton;
    [_host addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(nextView:)]];
    _setPads=[NSMutableArray new];
    for(int i=0;i<beat4::kSetCount;++i){
        UIButton *pad=[Beat4MiniButton buttonWithType:UIButtonTypeCustom];pad.tag=i;
        pad.titleLabel.font=Mono(8);pad.layer.cornerRadius=2;
        [pad addTarget:self action:@selector(selectSetPad:) forControlEvents:UIControlEventTouchUpInside];
        [pad addGestureRecognizer:[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(clearSetPad:)]];
        [self.view addSubview:pad];[_setPads addObject:pad];
    }
    _setButton=[Beat4MiniButton buttonWithType:UIButtonTypeCustom];
    [_setButton addTarget:self action:@selector(toggleSet:) forControlEvents:UIControlEventTouchUpInside];
    [_setButton addGestureRecognizer:[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(confirmResetSet:)]];
    [self.view addSubview:_setButton];
    _setEditButton=[Beat4MiniButton buttonWithType:UIButtonTypeCustom];
    [_setEditButton setTitle:@"/" forState:UIControlStateNormal];
    _setEditButton.accessibilityLabel=@"Éditer le SET / terminer";
    [_setEditButton addTarget:self action:@selector(editSet:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_setEditButton];
    _pgLabel=[self makeLabel:@"PC  ---" size:11 color:RGB(132,150,131)];
    _subLabel=[self makeLabel:@"SUB" size:10 color:RGB(123,136,122)];
    _levelLabel=[self makeLabel:@"LEVEL" size:10 color:RGB(123,136,122)];
    _kickButton=[self makeButton:@"KICK" size:13];
    [_kickButton addTarget:self action:@selector(toggleKick:) forControlEvents:UIControlEventTouchUpInside];
    _kickButton.accessibilityLabel=@"Kick on or off";
    _noteButton=[self makeButton:@"--" size:16];
    [self configureNoteMenu];
    _noteButton.accessibilityLabel=@"Song sub note";
    _levelSlider=[UISlider new];_levelSlider.minimumValue=0;_levelSlider.maximumValue=1;
    _levelSlider.minimumTrackTintColor=RGB(183,218,169);
    _levelSlider.maximumTrackTintColor=RGB(45,55,44);
    _levelSlider.thumbTintColor=RGB(220,225,205);
    [_levelSlider addTarget:self action:@selector(levelChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_levelSlider];
    _levelSlider.accessibilityLabel=@"Kick level";
    _songButton=[self makeButton:@"UNKNOWN" size:20];
    [_songButton addTarget:self action:@selector(editSong:) forControlEvents:UIControlEventTouchUpInside];
    _bpmButton=[self makeButton:@"--- BPM" size:27];
    UIPanGestureRecognizer *bpmPan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(dragBPM:)];
    bpmPan.maximumNumberOfTouches=1;
    [_bpmButton addGestureRecognizer:bpmPan];
    _bpmButton.accessibilityHint=@"Glisser horizontalement pour régler le BPM entier, un BPM par 4 points";
    _playButton=[self makeButton:@"▶" size:20];
    [_playButton addTarget:self action:@selector(playDown:) forControlEvents:UIControlEventTouchDown];
    [_playButton addTarget:self action:@selector(playUp:) forControlEvents:UIControlEventTouchUpInside];
    [_playButton addTarget:self action:@selector(playCancel:) forControlEvents:UIControlEventTouchCancel|UIControlEventTouchUpOutside];
    _playButton.accessibilityLabel=@"AUM PLAY/STOP (CC110/111 canal 16)";
    _pageRegion=[UIView new];[self.view addSubview:_pageRegion];
    _pads=[NSMutableArray new];
    for(int i=0;i<32;++i){
        UIButton *pad=[UIButton buttonWithType:UIButtonTypeCustom];pad.tag=i;
        pad.titleLabel.font=Mono(15);pad.layer.cornerRadius=4;
        [pad addTarget:self action:@selector(selectPad:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *edit=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(editPadQueue:)];
        [pad addGestureRecognizer:edit];
        [_pageRegion addSubview:pad];[_pads addObject:pad];
    }
    _modeControl=[[UISegmentedControl alloc]initWithItems:@[@"16",@"32"]];
    _modeControl.selectedSegmentIndex=[[self.unit transportSnapshot][@"cycleSteps"] integerValue]==32?1:0;
    _modeControl.accessibilityLabel=@"Cycle Drum 1 : 16 ou 32 steps";
    [_modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_modeControl];
    _rampToggle=[self makeButton:@"RAMPE" size:10];
    [_rampToggle addTarget:self action:@selector(toggleRamp:) forControlEvents:UIControlEventTouchUpInside];
    _rampDuration=[self makeButton:@"—" size:10];_rampDuration.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;
    _rampDuration.backgroundColor=RGB(190,234,178);_rampDuration.accessibilityLabel=@"Durée RAMPE";
    [_rampDuration setTitleColor:RGB(19,27,18) forState:UIControlStateNormal];
    _rampDuration.showsMenuAsPrimaryAction=YES;
    self.shownRampProgram=-2;self.shownRampBars=-2;
    _saveButton=[self makeButton:@"SAVE" size:10];
    [_saveButton setTitleColor:RGB(190,234,178) forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveRamp:) forControlEvents:UIControlEventTouchUpInside];
    [self refreshSong];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    const auto l=beat4::layoutFor(self.view.bounds.size.width,self.view.bounds.size.height);
    auto frame=[](beat4::Rect r){return CGRectMake(r.x,r.y,r.w,r.h);};
    _logo.frame=frame(l.logo);_logo.font=Mono(l.logoSize,UIFontWeightSemibold);
    _versionLabel.frame=frame(l.version);_versionLabel.font=Mono(l.versionSize);
    _host.frame=frame(l.viewTitle);
    for(int i=0;i<beat4::kSetCount;++i){_setPads[i].frame=frame(beat4::setPad(l,i));_setPads[i].titleLabel.font=Mono(MAX(6.,l.hostSize*.64));}
    _setButton.frame=frame(l.setToggle);_setButton.titleLabel.font=Mono(MAX(9.,l.hostSize));
    _setEditButton.frame=frame(l.setEditor);_setEditButton.titleLabel.font=Mono(MAX(11.,l.hostSize));_host.font=Mono(l.hostSize);_host.hidden=NO;
    _pgLabel.frame=frame(l.status);_pgLabel.font=Mono(l.transportsInHeader?12*l.scale:14*l.scale);
    self.canvas.lightBounds=frame(l.bars);[self.canvas setNeedsDisplay];
    _kickButton.frame=frame(l.kick);_kickButton.titleLabel.font=Mono(l.kickSize);
    _subLabel.frame=frame(l.subLabel);_subLabel.font=Mono(l.subSize);
    _noteButton.frame=frame(l.subValue);_noteButton.titleLabel.font=Mono(l.noteSize);
    _levelLabel.frame=frame(l.levelLabel);_levelLabel.font=Mono(l.levelSize);
    _levelSlider.frame=frame(l.levelSlider);
    // Match the visible capital-letter center to the slider track center.
    // UIKit centers line boxes; differing font sizes otherwise float vertically.
    const CGFloat rowCenter=l.portrait?CGRectGetMidY(frame(l.kick)):CGRectGetMidY(_levelSlider.frame);
    auto alignText=[](CGRect f,UIFont *font,CGFloat center){
        f.size.height=font.lineHeight;
        f.origin.y=center+font.capHeight/2-(font.ascender+font.descender)/2-f.size.height/2;
        return f;
    };
    _subLabel.frame=alignText(_subLabel.frame,_subLabel.font,rowCenter);
    _kickButton.frame=alignText(_kickButton.frame,_kickButton.titleLabel.font,rowCenter);
    _noteButton.frame=alignText(_noteButton.frame,_noteButton.titleLabel.font,rowCenter);
    _levelLabel.frame=alignText(_levelLabel.frame,_levelLabel.font,CGRectGetMidY(_levelSlider.frame));
    _bpmButton.frame=frame(l.bpm);_bpmButton.titleLabel.font=Mono(l.bpmSize,UIFontWeightMedium);
    _songButton.frame=frame(l.song);_songButton.titleLabel.font=Mono(l.songSize,UIFontWeightMedium);
    _songButton.titleLabel.adjustsFontSizeToFitWidth=YES;_songButton.titleLabel.minimumScaleFactor=.5;
    _playButton.frame=frame(l.toggle);_playButton.titleLabel.font=Mono((l.portrait?24:28)*l.scale);
    _pageRegion.frame=frame(l.bars);
    for(int i=0;i<32;++i)_pads[i].frame=frame(beat4::programPad({0,0,l.bars.w,l.bars.h},i));
    const CGFloat liveSize=MAX(10,MIN(18,l.modeSize)),liveHeight=liveSize*1.25;
    _hostBPM.font=Mono(liveSize);_hostBPM.frame=CGRectMake(l.bpm.x,l.bpm.y-liveHeight,l.bpm.w,liveHeight);
    const CGFloat square=MAX(6,MIN(12,liveSize*.7));
    self.canvas.beatSquareBounds=CGRectMake(l.bpm.x,l.bpm.y-liveHeight-square-3,4*square+12,square);
    const CGFloat size=MAX(8,MIN(l.modeSize,(self.view.bounds.size.width-2*l.modeLabel.x)/29)),
        height=MAX(l.modeControl.h,l.save.h),y=l.modeControl.y;
    CGFloat x=l.modeLabel.x;
    _modeLabel.frame=CGRectMake(x,y,3.65*size,height);_modeLabel.font=Mono(size);x+=3.65*size;
    _modeControl.frame=CGRectMake(x,y+(height-1.7*size)/2,11*size,1.7*size);x+=12.3*size;
    _rampToggle.frame=CGRectMake(x,y,3.85*size,height);x+=3.85*size;
    _rampDuration.frame=CGRectMake(x,y+(height-1.5*size)/2,2.7*size,1.5*size);x+=3.55*size;
    _rampDuration.layer.cornerRadius=.75*size;
    _saveButton.frame=CGRectMake(x,y,2.8*size,height);
    for(UIButton *button in @[_rampToggle,_rampDuration,_saveButton])button.titleLabel.font=Mono(size);
    _modeControl.selectedSegmentTintColor=RGB(190,234,178);
    [_modeControl setTitleTextAttributes:@{NSFontAttributeName:Mono(MAX(9.,l.modeSize)),NSForegroundColorAttributeName:RGB(228,235,220)} forState:UIControlStateNormal];
    [_modeControl setTitleTextAttributes:@{NSForegroundColorAttributeName:RGB(19,27,18)} forState:UIControlStateSelected];
    [self refreshPage];
}
- (void)configureNoteMenu {
    NSMutableArray<UIMenuElement*> *actions=[NSMutableArray new];
    for(int i=0;i<12;++i){
        NSString *label=[NSString stringWithUTF8String:beat4::noteName(i)];
        __weak Beat4ViewController *weakSelf = self;
        [actions addObject:[UIAction actionWithTitle:label image:nil identifier:nil handler:^(__kindof UIAction* act){
            (void)act;
            [weakSelf.unit saveSongSubNote:i];[weakSelf refreshSong];
        }]];
    }
    _noteButton.menu=[UIMenu menuWithChildren:actions];
    _noteButton.showsMenuAsPrimaryAction=YES;
}
- (void)configurationMessage:(NSString*)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"SONGS / SET" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showConfigurationMenu:(id)sender {
    (void)sender;
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"SONGS / SET" message:@"Importer ou sauvegarder les SONGS et les dix positions du SET." preferredStyle:UIAlertControllerStyleActionSheet];
    __weak Beat4ViewController *weakSelf=self;
    [menu addAction:[UIAlertAction actionWithTitle:@"Importer un fichier SONGS / SET" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initWithDocumentTypes:@[@"public.json"] inMode:UIDocumentPickerModeImport];
        picker.delegate=weakSelf;picker.allowsMultipleSelection=NO;[weakSelf presentViewController:picker animated:YES completion:nil];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Exporter SONGS / SET" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){(void)action;[weakSelf exportConfiguration];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Diagnostic MIDI" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){(void)action;[weakSelf showMIDIDiagnostic:nil];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView=_logo;menu.popoverPresentationController.sourceRect=_logo.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    (void)controller;NSURL *url=urls.firstObject;if(!url)return;
    BOOL access=[url startAccessingSecurityScopedResource];NSError *error=nil;NSNumber *size=nil;
    [url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
    NSData *data=nil;
    if(!error&&size.unsignedLongLongValue<=1024*1024)data=[NSData dataWithContentsOfURL:url options:0 error:&error];
    if(access)[url stopAccessingSecurityScopedResource];
    if(!data){[self configurationMessage:error.localizedDescription?:@"Fichier trop volumineux (maximum 1 Mo)."];return;}
    NSDictionary *summary=[self.unit previewConfigurationData:data error:&error];
    if(!summary){[self configurationMessage:error.localizedDescription];return;}
    NSString *message=[NSString stringWithFormat:@"%@ SONG(S), %@. Les champs absents seront conservés. Aucun PLAY, STOP ou PC ne sera envoyé.",summary[@"songs"],[summary[@"set"] boolValue]?@"SET inclus":@"SET conservé"];
    if([summary[@"unsupportedTempos"] intValue]>0)message=[message stringByAppendingFormat:@"\n%@ BPM seront mémorisés mais ne peuvent pas être transmis à AUM par le routage actuel (50–240 BPM).",summary[@"unsupportedTempos"]];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Charger la configuration ?" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    __weak Beat4ViewController *weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Charger" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;NSError *failure=nil;
        if([weakSelf.unit importConfigurationData:data error:&failure]){[weakSelf refreshSong];[weakSelf refreshPage];[weakSelf configurationMessage:@"Configuration chargée. Sauvegardez la session AUM pour la retrouver à sa réouverture."];}
        else [weakSelf configurationMessage:failure.localizedDescription];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)exportConfiguration {
    NSError *error=nil;NSData *data=[self.unit exportConfigurationData:&error];
    if(!data){[self configurationMessage:error.localizedDescription];return;}
    NSURL *directory=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    if(![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error]){[self configurationMessage:error.localizedDescription];return;}
    NSURL *url=[directory URLByAppendingPathComponent:@"BEAT4_SONGS_SET.json"];
    if(![data writeToURL:url options:NSDataWritingAtomic error:&error]){[self configurationMessage:error.localizedDescription];return;}
    UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[url] applicationActivities:nil];
    share.popoverPresentationController.sourceView=_logo;share.popoverPresentationController.sourceRect=_logo.bounds;
    share.completionWithItemsHandler=^(UIActivityType activity,BOOL completed,NSArray *items,NSError *failure){
        (void)activity;(void)completed;(void)items;(void)failure;[NSFileManager.defaultManager removeItemAtURL:directory error:nil];
    };
    [self presentViewController:share animated:YES completion:nil];
}
- (void)showMIDIDiagnostic:(id)sender {
    (void)sender;
    NSDictionary *s=[self.unit transportSnapshot];
    NSString *waiting=[s[@"awaitingTransport"] intValue]<0?@"aucune":([s[@"awaitingTransport"] boolValue]?@"PLAY":@"STOP");
    NSString *message=[NSString stringWithFormat:
        @"Start/Continue reçus : %@\nStop reçus : %@\nDernier message : %@\nCommandes envoyées à AUM : %@\nAttente de confirmation : %@\nAUM : %@\nRendu actif : %@\nSortie MIDI : %@\nDernier statut d’envoi : %@\nPC actif : %d · sélection : %d\nPhase incertaine : %@",
        s[@"receivedStart"],s[@"receivedStop"],s[@"lastRealtime"],s[@"sentTransport"],waiting,
        [s[@"transportValid"] boolValue]?([s[@"moving"] boolValue]?@"PLAY":@"arrêté"):@"inconnu",
        [s[@"hasRender"] boolValue]?@"oui":@"non",[s[@"midiOut"] boolValue]?@"disponible":@"absente",s[@"transportStatus"],
        [s[@"pg"] intValue]+1,[s[@"selectedPC"] intValue]+1,[s[@"uncertain"] boolValue]?@"oui":@"non"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Diagnostic MIDI" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Fermer" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)refreshSong {
    NSDictionary *state=self.frameSnapshot ?: [self.unit transportSnapshot];
    NSInteger pg=[state[@"pg"] integerValue];
    NSDictionary *song=[self.unit songForProgram:pg];
    NSInteger selected=[state[@"selectedPC"] integerValue];
    NSString *active=pg<0?@"ACTIVE —":[NSString stringWithFormat:@"ACTIVE PC %02ld%@",(long)pg+1,[state[@"estimated"] boolValue]?@" (estimé)":@""];
    NSString *pending=selected<0?@"":[NSString stringWithFormat:@" · SELECTED %02ld%@",(long)selected+1,[state[@"uncertain"] boolValue]?@" PHASE ?":@""];
    const int steps=[song[@"steps"] intValue]==32?32:16;
    _modeControl.selectedSegmentIndex=steps==32?1:0;
    _modeControl.enabled=pg>=0;
    [self refreshRamp:pg song:song];
    _pgLabel.text=[NSString stringWithFormat:@"%@%@",active,pending];
    BOOL configured=pg>=0;
    _noteButton.enabled=configured;_songButton.enabled=configured;_bpmButton.enabled=configured;
    NSString *name=song[@"title"] ?: @"UNKNOWN";
    [_songButton setTitle:name forState:UIControlStateNormal];
    double bpm=[song[@"bpm"] doubleValue];
    if(!self.bpmDragging)[_bpmButton setTitle:bpm>=20?[NSString stringWithFormat:@"%.0f BPM",std::round(bpm)]:@"--- BPM" forState:UIControlStateNormal];
    int note=[song[@"sub"] intValue];
    [_noteButton setTitle:[NSString stringWithUTF8String:beat4::noteName(note)] forState:UIControlStateNormal];
    BOOL enabled=[[self.unit transportSnapshot][@"kickEnabled"] boolValue];
    [_kickButton setTitleColor:enabled?RGB(177,225,164):RGB(110,120,111) forState:UIControlStateNormal];
}
- (void)editSong:(id)sender {
    (void)sender;if([self.unit currentProgram]<0)return;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"SONG NAME" message:@"Nom mémorisé pour ce PC" preferredStyle:UIAlertControllerStyleAlert];
    NSString *name=[self.unit currentSong][@"title"];
    [a addTextFieldWithConfigurationHandler:^(UITextField* field){field.text=[name isEqualToString:@"UNKNOWN"]?@"":name;
        field.placeholder=@"UNKNOWN";field.autocorrectionType=UITextAutocorrectionTypeNo;}];
    __weak Beat4ViewController *weakSelf = self;
    [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Enregistrer" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        (void)action;[weakSelf.unit saveSongTitle:a.textFields.firstObject.text ?: @""];[weakSelf refreshSong];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)dragBPM:(UIPanGestureRecognizer*)gesture {
    NSInteger pg=[self.unit currentProgram];
    if(gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed){self.bpmDragging=NO;[self refreshSong];return;}
    if(pg<0)return;
    if(gesture.state==UIGestureRecognizerStateBegan){
        self.bpmDragging=YES;
        self.bpmDragProgram=pg;
        double stored=[[self.unit currentSong][@"bpm"] doubleValue];
        double host=[[self.unit transportSnapshot][@"bpm"] doubleValue];
        self.bpmDragStart=beat4::initialDraggedBPM(stored,host);
        self.bpmDragOriginX=0;
    }
    if(!self.bpmDragging)return;
    if(pg!=self.bpmDragProgram){self.bpmDragging=NO;[self refreshSong];return;}
    if(gesture.state==UIGestureRecognizerStateChanged ||
       gesture.state==UIGestureRecognizerStateEnded){
        // Absolute displacement, not accumulated deltas: no runaway or drift.
        CGFloat dx=[gesture translationInView:self.view].x-self.bpmDragOriginX;
        double target=beat4::draggedBPM((int)self.bpmDragStart,dx);
        [_bpmButton setTitle:[NSString stringWithFormat:@"%.0f BPM",target] forState:UIControlStateNormal];
        if(gesture.state==UIGestureRecognizerStateEnded){
            [self.unit saveSongBPM:target program:self.bpmDragProgram];
            self.bpmDragging=NO;
            [self refreshSong];
        }
    }
    if(gesture.state==UIGestureRecognizerStateCancelled ||
       gesture.state==UIGestureRecognizerStateFailed)[self refreshSong];
}
- (void)toggleKick:(id)sender {
    (void)sender;
    BOOL state=[[self.unit transportSnapshot][@"kickEnabled"] boolValue];
    [self.unit setKickEnabled:!state];[self refreshSong];
}
- (void)levelChanged:(UISlider*)sender {[self.unit setKickLevel:sender.value];}
- (void)toggleTransport:(id)sender {(void)sender;[self.unit requestTransportToggle];}
- (void)modeChanged:(UISegmentedControl*)sender {
    [self.unit saveCycleSteps:sender.selectedSegmentIndex==1?32:16 program:[self.unit currentProgram]];[self refreshSong];
}
- (void)refreshRamp:(NSInteger)pc song:(NSDictionary *)song {
    NSDictionary *ramp=[self.unit rampForProgram:pc];
    NSInteger bars=[ramp[@"bars"] integerValue];BOOL named=pc>=0&&beat4::namedSong(song);
    BOOL enabled=named&&[ramp[@"enabled"] boolValue];
    _rampToggle.enabled=named&&bars>=0;_rampDuration.enabled=named;_saveButton.enabled=named&&[ramp[@"temporary"] boolValue];
    [_rampToggle setTitleColor:enabled?UIColor.whiteColor:RGB(137,145,138) forState:UIControlStateNormal];
    [_rampToggle setTitleColor:RGB(137,145,138) forState:UIControlStateDisabled];
    [_saveButton setTitleColor:RGB(86,100,83) forState:UIControlStateDisabled];
    _rampDuration.backgroundColor=named?RGB(190,234,178):RGB(21,23,24);
    [_rampDuration setTitleColor:RGB(228,235,220) forState:UIControlStateDisabled];
    [_rampDuration setTitle:bars<0?@"—":[NSString stringWithFormat:@"%ld",(long)bars] forState:UIControlStateNormal];
    if(self.shownRampProgram==pc&&self.shownRampBars==bars)return;
    self.shownRampProgram=pc;self.shownRampBars=bars;
    NSMutableArray<UIMenuElement *> *actions=[NSMutableArray new];
    __weak Beat4ViewController *weakSelf=self;
    for(NSInteger count=-1;count<=20;++count){
        NSString *title=count<0?@"—":[NSString stringWithFormat:@"%ld",(long)count];
        UIAction *item=[UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction *action){
                (void)action;Beat4ViewController *vc=weakSelf;if(!vc)return;
                NSDictionary *current=[vc.unit rampForProgram:pc];
                BOOL on=[current[@"enabled"] boolValue];
                if([current[@"bars"] intValue]<0&&![[vc.unit songForProgram:pc][@"rampEnabled"] isEqual:@NO])
                    on=!beat4::maskSong([vc.unit songForProgram:pc])&&![current[@"temporary"] boolValue];
                [vc.unit previewRamp:count enabled:on program:pc apply:NO];[vc refreshSong];
            }];
        item.state=count==bars?UIMenuElementStateOn:UIMenuElementStateOff;
        [actions addObject:item];
    }
    _rampDuration.menu=[UIMenu menuWithTitle:@"RAMPE · Mesures" children:actions];
}
- (void)toggleRamp:(id)sender {
    (void)sender;NSInteger pc=[self.unit currentProgram];NSDictionary *ramp=[self.unit rampForProgram:pc];
    NSInteger bars=[ramp[@"bars"] integerValue];if(bars<0)return;
    [self.unit previewRamp:bars enabled:![ramp[@"enabled"] boolValue] program:pc apply:YES];[self refreshSong];
}
- (void)saveRamp:(id)sender {
    (void)sender;[self.unit saveRampForProgram:[self.unit currentProgram]];[self refreshSong];
}
- (void)nextView:(id)sender {
    (void)sender;self.page=beat4::nextPage((int)self.page,1);[self refreshPage];
}
- (void)playDown:(id)sender {(void)sender;self.playPressTime=CACurrentMediaTime();}
- (void)playUp:(id)sender {
    (void)sender;
    // VoiceOver and keyboard activation can send TouchUpInside without TouchDown.
    [self.unit requestPlayGestureLong:self.playPressTime>0 && CACurrentMediaTime()-self.playPressTime>=beat4::PressRelease::longSeconds];
    self.playPressTime=0;
}
- (void)playCancel:(id)sender {(void)sender;self.playPressTime=0;}
- (void)toggleSet:(id)sender {
    (void)sender;[self.unit setEnabled:![[self.unit setSnapshot][@"on"] boolValue]];
}
- (void)editSet:(id)sender {
    (void)sender;self.setEditing=!self.setEditing;self.setEditPosition=-1;
    if(self.setEditing)self.page=1;[self refreshPage];
}
- (void)selectSetPad:(UIButton*)sender {
    if(self.setEditing){self.setEditPosition=sender.tag;[self refreshPage];}
    else [self.unit selectSetPosition:sender.tag];
}
- (void)clearSetPad:(UILongPressGestureRecognizer*)gesture {
    if(self.setEditing && gesture.state==UIGestureRecognizerStateBegan)
        [self.unit assignSetPosition:gesture.view.tag program:-1];
}
- (void)confirmResetSet:(UILongPressGestureRecognizer*)gesture {
    if(gesture.state!=UIGestureRecognizerStateBegan)return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"RESET CACHE SET" message:@"Revenir au premier pad renseigné. Le SONG actif, les dix affectations et le QUEUE sont conservés." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    __weak Beat4ViewController *weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Confirmer" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;[weakSelf.unit resetSetCache];
    }]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)selectPad:(UIButton*)sender {
    NSInteger pc=(self.page-1)*32+sender.tag;self.editedPC=pc;
    if(self.setEditing){
        if(self.setEditPosition>=0)[self.unit assignSetPosition:self.setEditPosition program:pc];
    }else [self.unit selectProgram:pc];[self refreshPage];
}
- (void)editPadQueue:(UILongPressGestureRecognizer*)gesture {
    if(self.setEditing || gesture.state!=UIGestureRecognizerStateBegan)return;
    self.editedPC=(self.page-1)*32+gesture.view.tag;
    const NSInteger pc=self.editedPC;
    NSArray *labels=@[@"Rouge",@"Jaune moutarde",@"Vert foncé",@"Rose",@"Bleu",@"Saumon",@"Vert vif",@"Orange"];
    NSDictionary *song=[self.unit songForProgram:pc];
    NSString *title=[NSString stringWithFormat:@"Couleur · PCh %02ld%@",(long)pc+1,
        beat4::namedSong(song)?[NSString stringWithFormat:@" · %@",song[@"title"]]:@""];
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    __weak Beat4ViewController *weakSelf=self;
    for(NSUInteger i=0;i<labels.count;++i){
        NSString *color=beat4::rampPaletteNames()[i];
        [menu addAction:[UIAlertAction actionWithTitle:labels[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            (void)action;[weakSelf.unit savePadColor:color program:pc];[weakSelf refreshPage];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Couleur par défaut" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;[weakSelf.unit savePadColor:@"" program:pc];[weakSelf refreshPage];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Modifier QUEUE" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;weakSelf.editedPC=pc;[weakSelf editQueue:nil];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)editQueue:(id)sender {
    (void)sender;const NSInteger pc=self.editedPC;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"QUEUE · SONG %02ld",(long)pc+1]
        message:@"Le cycle du projet ACTIF détermine l’attente : 16 steps = 1 mesure, 32 = 2 mesures. Par défaut : 16. La rampe démarre quand le projet devient actif."
        preferredStyle:UIAlertControllerStyleAlert];
    __weak Beat4ViewController *weakSelf=self;
    NSArray *titles=@[@"16 steps · 1 mesure",@"32 steps · 2 mesures"];
    for(NSInteger i=0;i<2;++i){
        const NSInteger steps=i==1?32:16;
        [a addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            (void)action;[weakSelf.unit saveCycleSteps:steps program:pc];[weakSelf refreshPage];[weakSelf refreshSong];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)refreshPage {
    NSString *title=self.page==0?@"MÉTRONOME":self.page==1?@"PC 01–32":@"PC 33–64";
    _host.text=title;
    _host.accessibilityLabel=[title stringByAppendingString:@", vue suivante"];

    if(self.canvas.showBars!=(self.page==0)){self.canvas.showBars=self.page==0;[self.canvas setNeedsDisplay];}
    NSDictionary *state=self.frameSnapshot ?: [self.unit transportSnapshot];
    int active=[state[@"pg"] intValue],selected=[state[@"selectedPC"] intValue];
    for(int i=0;i<32;++i){
        UIButton *pad=_pads[i];pad.hidden=self.page==0;int pc=((int)self.page-1)*32+i;
        NSDictionary *song=[self.unit songForProgram:pc];NSString *name=song[@"title"];
        const BOOL configured=beat4::namedSong(song);
        NSString *overrideColor=song[@"padColor"];
        const NSInteger color=(configured||overrideColor.length)?circuitColorIndex(pc,overrideColor):-1;
        [pad setTitle:configured?name:[NSString stringWithFormat:@"%02d",pc+1] forState:UIControlStateNormal];
        pad.titleLabel.adjustsFontSizeToFitWidth=YES;pad.titleLabel.minimumScaleFactor=.55;
        pad.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
        const CGFloat font=MAX(9,MIN(15,pad.bounds.size.width*.30));pad.titleLabel.font=Mono(configured?.8*font:font);
        pad.backgroundColor=color>=0?circuitColor(color):(configured?RGB(27,50,35):RGB(25,29,26));
        [pad setTitleColor:color<0?RGB(190,196,187):(color==1||color>=5?RGB(16,16,16):UIColor.whiteColor) forState:UIControlStateNormal];
        pad.layer.borderWidth=pc==active||pc==selected?2:0;
        pad.layer.borderColor=(pc==active?UIColor.whiteColor:RGB(235,155,65)).CGColor;
        pad.accessibilityLabel=[NSString stringWithFormat:@"PCh %02d %@ %@",pc+1,configured?name:@"",pc==active?@"ACTIF":pc==selected?@"EN ATTENTE":@""];
    }
    NSDictionary *set=[self.unit setSnapshot];NSArray *slots=set[@"slots"];
    const int cursor=[set[@"cursor"] intValue];
    [_setButton setTitle:[set[@"on"] boolValue]?@"SET ON":@"SET OFF" forState:UIControlStateNormal];
    [_setButton setTitleColor:[set[@"on"] boolValue]?RGB(177,225,164):RGB(115,128,114) forState:UIControlStateNormal];
    [_setEditButton setTitleColor:self.setEditing?RGB(235,155,65):RGB(150,166,147) forState:UIControlStateNormal];
    for(int i=0;i<beat4::kSetCount;++i){
        UIButton *pad=_setPads[i];const int pc=[slots[i] intValue];
        const int occurrence=[set[@"activePosition"] intValue],queuedIndex=[set[@"queuedPosition"] intValue];
        const BOOL filled=pc>=0,lit=filled&&pc==active&&(occurrence<0||occurrence==i),queued=filled&&pc==selected&&(queuedIndex<0||queuedIndex==i);
        pad.hidden=NO;pad.backgroundColor=!filled?RGB(15,19,16):i==cursor?RGB(92,98,91):RGB(40,46,40);
        [pad setTitle:filled?[NSString stringWithFormat:@"%02d",pc+1]:@"·" forState:UIControlStateNormal];
        [pad setTitleColor:lit?RGB(218,239,199):RGB(146,156,142) forState:UIControlStateNormal];
        pad.layer.borderWidth=i==cursor||queued||(self.setEditing&&i==self.setEditPosition)?1:0;
        pad.layer.borderColor=(queued?RGB(235,155,65):RGB(163,182,155)).CGColor;
        pad.accessibilityLabel=[NSString stringWithFormat:@"SET %d, %@%@%@%@",i+1,
            filled?[NSString stringWithFormat:@"SONG %02d",pc+1]:@"vide",i==cursor?@", curseur":@"",lit?@", actif":@"",queued?@", queued":@""];
    }

}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.clock=[CADisplayLink displayLinkWithTarget:self selector:@selector(updateDisplay:)];
    self.clock.preferredFramesPerSecond=60;
    [self.clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];[self.clock invalidate];self.clock=nil;
}
- (void)updateDisplay:(CADisplayLink*)link {
    const CFTimeInterval now=link?link.timestamp:CACurrentMediaTime();
    const uint64_t revision=[self.unit displayRevision];
    const bool watchdog=self.lastWatchdog==0 || now-self.lastWatchdog>=.25;
    if(link && !self.lastMoving && ![self.canvas lightsAnimating] && revision==self.seenRevision && !watchdog)return;
    if(watchdog)self.lastWatchdog=now;
    NSDictionary *data=[self.unit transportSnapshot];self.frameSnapshot=data;
    if(!link || self.lastSynced!=[data[@"synced"] boolValue] || self.lastMoving || [data[@"moving"] boolValue] || [self.canvas lightsAnimating] || revision!=self.seenRevision)self.canvas.snapshot=data;
    NSInteger pg=[data[@"pg"] integerValue];
    if(pg!=self.seenPG){self.seenPG=pg;[self refreshSong];}
    BOOL synced=[data[@"synced"] boolValue];
    BOOL moving=[data[@"moving"] boolValue];
    BOOL setOn=[[self.unit setSnapshot][@"on"] boolValue];
    [_playButton setTitle:moving&&!setOn?@"■":@"▶" forState:UIControlStateNormal];
    _playButton.accessibilityLabel=moving?(setOn?@"SONG suivant, appui long pour arrêter":@"Arrêter"):@"Démarrer";
    [self refreshSong];[self refreshPage];
    double target=[[self.unit currentSong][@"bpm"] doubleValue];
    const double host=[data[@"bpm"] doubleValue];
    NSString *tempo=host>0?[[NSString stringWithFormat:@"%.1f",host] stringByReplacingOccurrencesOfString:@"." withString:@","]:@"—";
    if([tempo hasSuffix:@",0"])tempo=[tempo substringToIndex:tempo.length-2];
    _hostBPM.text=[NSString stringWithFormat:@"HOST %@ BPM",tempo];
    const bool matches=host>0&&std::round(target*10)==std::round(host*10);
    [_bpmButton setTitleColor:beat4::validBPM(target)?(matches?UIColor.whiteColor:RGB(235,155,65)):RGB(110,120,111) forState:UIControlStateNormal];
    BOOL enabled=[data[@"kickEnabled"] boolValue];
    [_kickButton setTitleColor:enabled?RGB(177,225,164):RGB(110,120,111) forState:UIControlStateNormal];
    if(!_levelSlider.tracking)_levelSlider.value=[data[@"kickLevel"] floatValue];
    self.lastMoving=moving;self.lastSynced=synced;self.seenRevision=revision;
}
@end
