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

static UIColor *RGB(CGFloat r,CGFloat g,CGFloat b,CGFloat a=1){
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}
static UIFont *Mono(CGFloat sz,UIFontWeight w=UIFontWeightRegular){
    return [UIFont monospacedSystemFontOfSize:sz weight:w];
}
static NSString *MMCName(int command){
    if(command==0x02)return @"PLAY";
    if(command==0x09)return @"PAUSE";
    if(command==0x01)return @"STOP";
    if(command==0x05)return @"REW";
    return @"--";
}
@interface Beat4Button : UIButton @end
@implementation Beat4Button
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    (void)event;
    const CGFloat dx=MAX(0,(44-CGRectGetWidth(self.bounds))*.5);
    const CGFloat dy=MAX(0,(44-CGRectGetHeight(self.bounds))*.5);
    return CGRectContainsPoint(CGRectInset(self.bounds,-dx,-dy),point);
}
@end
@interface Beat4Canvas : UIView {
    beat4::Lights _lights;
    CFTimeInterval _lightTick;
}
- (BOOL)lightsAnimating;
@property(nonatomic,copy)NSDictionary<NSString*,NSNumber*> *snapshot;
@property(nonatomic,assign)CGRect lightBounds;
@end
@implementation Beat4Canvas
- (void)setSnapshot:(NSDictionary<NSString*,NSNumber*>*)snapshot {
    const CFTimeInterval now=CACurrentMediaTime();
    const double dt=_lightTick>0?now-_lightTick:0;_lightTick=now;
    const bool moving=[snapshot[@"moving"] boolValue];
    const bool rewound=[snapshot[@"mode"] intValue]==static_cast<int>(beat4::HostMode::Rewound);
    const bool stopped=[snapshot[@"localCommand"] intValue]==1 || rewound;
    const double displayBeat=[snapshot[@"displayBeat"] doubleValue];
    _lights.update(displayBeat,moving,[snapshot[@"synced"] boolValue],stopped,dt,
                   [snapshot[@"bpm"] doubleValue]);
    _snapshot=[snapshot copy];[self setNeedsDisplay];
}
- (BOOL)lightsAnimating {return _lights.animating();}
- (void)drawRect:(CGRect)rect {
    [[UIColor colorWithRed:.028 green:.035 blue:.030 alpha:1] setFill]; UIRectFill(rect);
    const CGRect area=self.lightBounds;
    const CGFloat gap=static_cast<CGFloat>(beat4::beatBarGap(area.size.width));
    const CGFloat bw=(area.size.width-3*gap)/4;
    CGContextRef ctx=UIGraphicsGetCurrentContext();
    if(!ctx || bw<=0)return;
    for(int i=0;i<4;++i){
        CGRect r=CGRectMake(CGRectGetMinX(area)+i*(bw+gap),CGRectGetMinY(area),bw,CGRectGetHeight(area));
        const CGFloat energy=static_cast<CGFloat>(_lights.energy(i));
        const CGFloat corner=std::max((CGFloat)3,std::min((CGFloat)7,bw*.10));
        UIBezierPath *shape=[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:corner];
        // The physical segment remains visible at rest, with no animated core.
        [RGB(24,32,24,1) setFill];[shape fill];
        CGContextSaveGState(ctx);
        if(energy>.001){
            CGContextSetShadowWithColor(ctx,CGSizeZero,10+energy*30,RGB(178,221,159,.16+.34*energy).CGColor);
            [RGB(62+142*energy,78+154*energy,54+128*energy,.35+.65*energy) setFill];
            [shape fill];
        }
        CGContextRestoreGState(ctx);
        if(energy>.001){
            const CGFloat topR=(52+174*energy)/255.0, topG=(68+178*energy)/255.0, topB=(46+156*energy)/255.0;
            const CGFloat midR=(32+158*energy)/255.0, midG=(45+183*energy)/255.0, midB=(29+144*energy)/255.0;
            const CGFloat botR=(22+112*energy)/255.0, botG=(30+137*energy)/255.0, botB=(21+101*energy)/255.0;
            const CGFloat components[]={topR,topG,topB,1, midR,midG,midB,1, botR,botG,botB,1};
            const CGFloat locations[]={0,.52,1};
            CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient=CGGradientCreateWithColorComponents(space,components,locations,3);
            CGContextSaveGState(ctx);
            [shape addClip];
            CGContextDrawLinearGradient(ctx,gradient,CGPointMake(CGRectGetMidX(r),CGRectGetMinY(r)),
                                        CGPointMake(CGRectGetMidX(r),CGRectGetMaxY(r)),0);
            CGContextRestoreGState(ctx);
            CGGradientRelease(gradient);CGColorSpaceRelease(space);
        }
        CGContextSaveGState(ctx);
        CGContextSetStrokeColorWithColor(ctx,RGB(95,115,91,.13).CGColor);
        CGContextSetLineWidth(ctx,.6);
        [shape stroke];
        CGContextRestoreGState(ctx);
    }
}
@end

@interface Beat4ViewController ()
@property(nonatomic,strong)Beat4AudioUnit *unit;
@property(nonatomic,strong)Beat4Canvas *canvas;
@property(nonatomic,strong)CADisplayLink *clock;
@property(nonatomic,strong)UILabel *logo,*versionLabel,*host,*diagnostics,*pgLabel,*subLabel,*levelLabel;
@property(nonatomic,strong)UIButton *kickButton,*noteButton,*songButton,*bpmButton;
@property(nonatomic,strong)UIButton *playButton,*pauseButton,*stopButton;
@property(nonatomic,strong)UISlider *levelSlider;
@property(nonatomic,assign)NSInteger seenPG;
@property(nonatomic,assign)uint64_t seenRevision;
@property(nonatomic,assign)CFTimeInterval lastWatchdog;
@property(nonatomic,assign)BOOL lastMoving,lastSynced;
@property(nonatomic,assign)BOOL bpmDragging;
@property(nonatomic,assign)NSInteger bpmDragProgram,bpmDragStart,bpmDragValue;
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
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:text forState:UIControlStateNormal];[b setTitleColor:RGB(219,223,209) forState:UIControlStateNormal];
    b.titleLabel.font=Mono(size,UIFontWeightMedium);
    b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    [self.view addSubview:b];return b;
}
- (UIButton *)makeTransportButton:(NSString *)text size:(CGFloat)size {
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
    self.seenPG=-999;
    self.seenRevision=0;self.lastWatchdog=0;
    _logo=[self makeLabel:@"BEAT//4" size:20 color:RGB(220,224,212)];
    _logo.font=Mono(20,UIFontWeightSemibold);
    NSString *version=[[NSBundle bundleForClass:self.class] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    _versionLabel=[self makeLabel:[NSString stringWithFormat:@"v%@",version] size:8 color:RGB(91,106,90)];
    _host=[self makeLabel:@"AUM  •  WAIT" size:11 color:RGB(144,161,140)];_host.textAlignment=NSTextAlignmentRight;
    _diagnostics=[self makeLabel:@"RENDER WAIT | TRANSPORT WAIT | MUSICAL WAIT | MMC WAIT" size:8 color:RGB(117,133,114)];
    _diagnostics.adjustsFontSizeToFitWidth=YES;_diagnostics.minimumScaleFactor=.55;
    _pgLabel=[self makeLabel:@"PG  ---" size:11 color:RGB(132,150,131)];
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
    bpmPan.minimumNumberOfTouches=1;bpmPan.maximumNumberOfTouches=1;
    [_bpmButton addGestureRecognizer:bpmPan];
    _bpmButton.accessibilityLabel=@"Song BPM";
    _bpmButton.accessibilityHint=@"Glisser horizontalement, quatre points par BPM";
    _playButton=[self makeTransportButton:@"▶" size:20];
    _pauseButton=[self makeTransportButton:@"Ⅱ" size:20];
    _stopButton=[self makeTransportButton:@"■" size:20];
    [_playButton addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    [_pauseButton addTarget:self action:@selector(pause:) forControlEvents:UIControlEventTouchUpInside];
    [_stopButton addTarget:self action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
    _playButton.accessibilityLabel=@"Start transport";
    _playButton.accessibilityHint=@"Appui long pour choisir MIDI CC ou MMC";
    [self configureTransportMenu];
    [self refreshSong];
}
- (void)configureTransportMenu {
    const BOOL cc=[self.unit safetyMIDIEnabled];
    __weak Beat4ViewController *weakSelf=self;
    UIAction *safe=[UIAction actionWithTitle:@"Secours MIDI CC — START/STOP" image:nil identifier:nil handler:^(__kindof UIAction *action){
        (void)action;[weakSelf.unit setSafetyMIDIEnabled:YES];[weakSelf configureTransportMenu];
    }];
    safe.state=cc?UIMenuElementStateOn:UIMenuElementStateOff;
    UIAction *mmc=[UIAction actionWithTitle:@"MMC — START/PAUSE/STOP" image:nil identifier:nil handler:^(__kindof UIAction *action){
        (void)action;[weakSelf.unit setSafetyMIDIEnabled:NO];[weakSelf configureTransportMenu];
    }];
    mmc.state=cc?UIMenuElementStateOff:UIMenuElementStateOn;
    _playButton.menu=[UIMenu menuWithTitle:@"Transport AUM" children:@[safe,mmc]];
    _playButton.showsMenuAsPrimaryAction=NO;
    [_playButton setTitle:cc?@"▶ CC":@"▶ MMC" forState:UIControlStateNormal];
    _playButton.titleLabel.font=Mono(11,UIFontWeightMedium);
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    const beat4::Layout l=beat4::layoutFor(self.view.bounds.size.width,self.view.bounds.size.height);
    auto frame=[](beat4::Rect r) {return CGRectMake(r.x,r.y,r.w,r.h);};
    _logo.frame=frame(l.logo);
    _versionLabel.frame=frame(l.version);
    _host.frame=frame(l.host);
    _diagnostics.frame=frame(l.diagnostics);
    _host.hidden=l.transportsInHeader && self.view.bounds.size.width<380;
    _pgLabel.frame=frame(l.pg);
    _pgLabel.hidden=NO;
    self.canvas.lightBounds=frame(l.bars);
    [self.canvas setNeedsDisplay];
    _kickButton.frame=frame(l.kick);
    _subLabel.frame=frame(l.subLabel);
    _noteButton.frame=frame(l.subValue);
    _levelLabel.frame=frame(l.levelLabel);
    _levelSlider.frame=frame(l.levelSlider);
    _bpmButton.frame=frame(l.bpm);
    _songButton.frame=frame(l.song);
    _playButton.frame=frame(l.play);
    _pauseButton.frame=frame(l.pause);
    _stopButton.frame=frame(l.stop);
    // The rhythm display remains dominant; labels scale down, not the bars.
    BOOL narrow=self.view.bounds.size.width<520;
    _bpmButton.titleLabel.font=Mono(narrow?19:27,UIFontWeightMedium);
    _songButton.titleLabel.font=Mono(narrow?16:20,UIFontWeightMedium);
    _logo.font=Mono(narrow?17:20,UIFontWeightSemibold);
    _versionLabel.font=Mono(8);
    _pgLabel.font=Mono(l.transportsInHeader?9:11);
    _diagnostics.font=Mono(l.transportsInHeader?7:8);
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
- (void)refreshSong {
    NSDictionary *song=[self.unit currentSong];
    NSInteger pg=[self.unit currentProgram];
    _pgLabel.text=pg<0?@"PG ---":[NSString stringWithFormat:@"PG %03ld",(long)pg];
    BOOL configured=pg>=0;
    _noteButton.enabled=configured;_songButton.enabled=configured;_bpmButton.enabled=configured;
    NSString *name=song[@"title"] ?: @"UNKNOWN";
    [_songButton setTitle:name forState:UIControlStateNormal];
    double bpm=[song[@"bpm"] doubleValue];
    if(!self.bpmDragging || self.bpmDragProgram!=pg)
        [_bpmButton setTitle:bpm>=20?[NSString stringWithFormat:@"%ld BPM",(long)std::lround(bpm)]:@"--- BPM"
                    forState:UIControlStateNormal];
    int note=[song[@"sub"] intValue];
    [_noteButton setTitle:[NSString stringWithUTF8String:beat4::noteName(note)] forState:UIControlStateNormal];
    BOOL enabled=[[self.unit transportSnapshot][@"kickEnabled"] boolValue];
    [_kickButton setTitleColor:enabled?RGB(177,225,164):RGB(110,120,111) forState:UIControlStateNormal];
}
- (void)editSong:(id)sender {
    (void)sender;if([self.unit currentProgram]<0)return;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"SONG NAME" message:@"Nom mémorisé pour ce PG" preferredStyle:UIAlertControllerStyleAlert];
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
    if(gesture.state==UIGestureRecognizerStateBegan){
        const NSInteger pg=[self.unit currentProgram];
        if(!beat4::validProgram((int)pg))return;
        const double saved=[[self.unit currentSong][@"bpm"] doubleValue];
        const double host=[[[self.unit transportSnapshot] objectForKey:@"bpm"] doubleValue];
        self.bpmDragProgram=pg;
        self.bpmDragStart=beat4::initialDraggedBPM(saved,host);
        self.bpmDragValue=self.bpmDragStart;
        self.bpmDragging=YES;
        [_bpmButton setTitle:[NSString stringWithFormat:@"%ld BPM",(long)self.bpmDragValue]
                    forState:UIControlStateNormal];
        return;
    }
    if(!self.bpmDragging)return;
    const BOOL sameProgram=[self.unit currentProgram]==self.bpmDragProgram;
    if(gesture.state==UIGestureRecognizerStateChanged && sameProgram){
        const CGFloat dx=[gesture translationInView:self.view].x;
        const NSInteger next=beat4::draggedBPM((int)self.bpmDragStart,dx);
        if(next!=self.bpmDragValue){
            self.bpmDragValue=next;
            [_bpmButton setTitle:[NSString stringWithFormat:@"%ld BPM",(long)next]
                        forState:UIControlStateNormal];
        }
        return;
    }
    if(gesture.state==UIGestureRecognizerStateEnded ||
       gesture.state==UIGestureRecognizerStateCancelled ||
       gesture.state==UIGestureRecognizerStateFailed || !sameProgram){
        const BOOL save=gesture.state==UIGestureRecognizerStateEnded && sameProgram;
        const NSInteger value=self.bpmDragValue;
        self.bpmDragging=NO;
        if(save)[self.unit saveSongBPM:value];
        [self refreshSong];
    }
}
- (void)toggleKick:(id)sender {
    (void)sender;
    BOOL state=[[self.unit transportSnapshot][@"kickEnabled"] boolValue];
    [self.unit setKickEnabled:!state];[self refreshSong];
}
- (void)levelChanged:(UISlider*)sender {[self.unit setKickLevel:sender.value];}
- (void)play:(id)sender {(void)sender;[self.unit requestMMC:0x02];}
- (void)pause:(id)sender {(void)sender;[self.unit requestMMC:0x09];}
- (void)stop:(id)sender {(void)sender;[self.unit requestMMC:0x01];}
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
    const uint64_t revision=[self.unit displayRevision];
    const BOOL revisionChanged=revision!=self.seenRevision;
    const BOOL watchdogDue=self.lastWatchdog==0 || link.timestamp-self.lastWatchdog>=1.0;
    const auto decision=beat4::displayDecision(self.lastMoving||[self.canvas lightsAnimating],revisionChanged,watchdogDue);
    if(!decision.readSnapshot)return;
    if(watchdogDue)self.lastWatchdog=link.timestamp;
    NSDictionary *data=[self.unit transportSnapshot];
    NSInteger pg=[data[@"pg"] integerValue];
    if(pg!=self.seenPG){self.seenPG=pg;[self refreshSong];}
    BOOL synced=[data[@"synced"] boolValue];
    BOOL moving=[data[@"moving"] boolValue];
    const BOOL canvasChanged=beat4::canvasShouldRedraw(moving,
        synced!=self.lastSynced,moving!=self.lastMoving);
    if(canvasChanged || revisionChanged || [self.canvas lightsAnimating])self.canvas.snapshot=data;
    NSString *host=synced?[NSString stringWithFormat:@"AUM %.1f %@",[data[@"bpm"] doubleValue],moving?@"▶":@"Ⅱ"] : (![data[@"hasRender"] boolValue]?@"AUM NO RENDER":@"AUM NO HOST");
    if(![_host.text isEqualToString:host])_host.text=host;
    NSString *render=[data[@"hasRender"] boolValue]?@"RENDER OK":@"RENDER STALE";
    NSString *transport=([data[@"transportCallback"] boolValue]&&[data[@"transportReturned"] boolValue])?@"TRANSPORT OK":@"TRANSPORT WAIT";
    NSString *musical=([data[@"musicalCallback"] boolValue]&&[data[@"musicalReturned"] boolValue])?@"MUSICAL OK":@"MUSICAL WAIT";
    const int pending=[data[@"mmcPending"] intValue];
    const int acknowledged=[data[@"mmcAcknowledged"] intValue];
    const int requestAttempts=[data[@"mmcRequestAttempts"] intValue];
    NSString *mmc=nil;
    if(![data[@"midiOut"] boolValue])mmc=@"MMC NO CALLBACK";
    else if(pending)mmc=[NSString stringWithFormat:@"MMC %@ %d/3",MMCName(pending),requestAttempts];
    else if([data[@"mmcFailed"] boolValue]){
        const int status=[data[@"mmcLastStatus"] intValue];
        mmc=status==noErr?@"MMC NO ACK":[NSString stringWithFormat:@"MMC SEND %d",status];
    }else if(acknowledged)mmc=[NSString stringWithFormat:@"MMC ACK %@",MMCName(acknowledged)];
    else mmc=@"MMC READY";
    if([data[@"safetyEnabled"] boolValue]){
        const int cc=[data[@"safetyLastCC"] intValue];
        mmc=[NSString stringWithFormat:@"CC%d #%llu status %d | %@",cc,
            [data[@"safetyAttempts"] unsignedLongLongValue],[data[@"safetyLastStatus"] intValue],mmc];
    }
    NSString *diagnostics=[NSString stringWithFormat:@"%@ | %@ | %@ | %@ | BPM %.1f | %@",
        render,transport,musical,moving?@"PLAY":@"STOP",[data[@"bpm"] doubleValue],mmc];
    if(![_diagnostics.text isEqualToString:diagnostics])_diagnostics.text=diagnostics;
    BOOL enabled=[data[@"kickEnabled"] boolValue];
    UIColor *kickColor=enabled?RGB(177,225,164):RGB(110,120,111);
    if(![[_kickButton titleColorForState:UIControlStateNormal] isEqual:kickColor])
        [_kickButton setTitleColor:kickColor forState:UIControlStateNormal];
    const float kickLevel=[data[@"kickLevel"] floatValue];
    if(!_levelSlider.tracking && std::abs(_levelSlider.value-kickLevel)>.0001f)
        _levelSlider.value=kickLevel;
    self.seenRevision=revision;self.lastMoving=moving;self.lastSynced=synced;
}
@end
