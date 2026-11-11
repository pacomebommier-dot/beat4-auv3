#import "Beat4ViewController.h"
#import "Beat4AudioUnit.h"
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <cmath>
#include <algorithm>
#include "Beat4Kick.hpp"
#include "Beat4Songs.hpp"
#include "Beat4Layout.hpp"

static UIColor *RGB(CGFloat r,CGFloat g,CGFloat b,CGFloat a=1){
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}
static UIFont *Mono(CGFloat sz,UIFontWeight w=UIFontWeightRegular){
    return [UIFont monospacedSystemFontOfSize:sz weight:w];
}
@interface Beat4Canvas : UIView
@property(nonatomic,copy)NSDictionary<NSString*,NSNumber*> *snapshot;
@property(nonatomic,assign)CGRect lightBounds;
@end
@implementation Beat4Canvas
- (void)setSnapshot:(NSDictionary<NSString*,NSNumber*>*)snapshot {
    _snapshot=[snapshot copy];[self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    [[UIColor colorWithRed:.028 green:.035 blue:.030 alpha:1] setFill]; UIRectFill(rect);
    const BOOL synced=[self.snapshot[@"synced"] boolValue];
    const BOOL moving=[self.snapshot[@"moving"] boolValue];
    const int active=[self.snapshot[@"active"] intValue];
    const double fraction=[self.snapshot[@"fraction"] doubleValue];
    const CGFloat pulse=(synced&&moving)?static_cast<CGFloat>(beat4::pulseBrightness(fraction)):0;
    const CGRect area=self.lightBounds;
    const CGFloat gap=std::max((CGFloat)18,std::min((CGFloat)56,area.size.width*.105));
    const CGFloat bw=(area.size.width-3*gap)/4;
    CGContextRef ctx=UIGraphicsGetCurrentContext();
    if(!ctx || bw<=0)return;
    for(int i=0;i<4;++i){
        CGRect r=CGRectMake(CGRectGetMinX(area)+i*(bw+gap),CGRectGetMinY(area),bw,CGRectGetHeight(area));
        CGFloat energy=(synced&&moving&&i==active)?pulse:0;
        if(synced&&!moving&&i==active)energy=.18;
        const CGFloat corner=std::max((CGFloat)3,std::min((CGFloat)7,bw*.10));
        UIBezierPath *shape=[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:corner];
        CGContextSaveGState(ctx);
        if(energy>.015){
            CGContextSetShadowWithColor(ctx,CGSizeZero,14+energy*28,RGB(178,221,159,.30*energy).CGColor);
            [RGB(172,214,153,.16+.42*energy) setFill];[shape fill];
            CGContextSetShadowWithColor(ctx,CGSizeZero,8+energy*12,RGB(210,244,202,.3*energy).CGColor);
        }
        // Even at rest all four physical phosphor segments are readable in darkness.
        [RGB(26+180*energy,35+205*energy,26+164*energy,1) setFill];[shape fill];
        CGContextRestoreGState(ctx);
        CGRect core=CGRectInset(r,bw*.13,bw*.10);
        if(energy>.01 && core.size.width>1 && core.size.height>1){
            UIBezierPath *inner=[UIBezierPath bezierPathWithRoundedRect:core cornerRadius:std::max(2.0,corner*.50)];
            [RGB(218,248,208,.14+energy*.60) setFill];[inner fill];
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
@property(nonatomic,strong)UILabel *logo,*host,*pgLabel,*subLabel,*levelLabel;
@property(nonatomic,strong)UIButton *kickButton,*noteButton,*songButton,*bpmButton;
@property(nonatomic,strong)UIButton *playButton,*pauseButton,*stopButton;
@property(nonatomic,strong)UISlider *levelSlider;
@property(nonatomic,assign)NSInteger seenPG;
@property(nonatomic,assign)double bpmDragStart;
@property(nonatomic,assign)CGFloat bpmDragOriginX;
@property(nonatomic,assign)NSInteger bpmDragProgram;
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
- (void)loadView {
    Beat4Canvas *canvas=[[Beat4Canvas alloc]initWithFrame:CGRectMake(0,0,720,400)];
    canvas.backgroundColor=RGB(7,9,8);self.canvas=canvas;self.view=canvas;
    self.preferredContentSize=CGSizeMake(720,400);
    self.seenPG=-999;
    _logo=[self makeLabel:@"BEAT//4" size:20 color:RGB(220,224,212)];
    _logo.font=Mono(20,UIFontWeightSemibold);
    _host=[self makeLabel:@"AUM  •  WAIT" size:11 color:RGB(144,161,140)];_host.textAlignment=NSTextAlignmentRight;
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
    bpmPan.maximumNumberOfTouches=1;
    [_bpmButton addGestureRecognizer:bpmPan];
    _bpmButton.accessibilityHint=@"Glisser horizontalement pour régler le BPM entier, un BPM par 9 points";
    _playButton=[self makeButton:@"▶" size:20];
    _pauseButton=[self makeButton:@"Ⅱ" size:20];
    _stopButton=[self makeButton:@"■" size:20];
    [_playButton addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    [_pauseButton addTarget:self action:@selector(pause:) forControlEvents:UIControlEventTouchUpInside];
    [_stopButton addTarget:self action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
    [self refreshSong];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    const beat4::Layout l=beat4::layoutFor(self.view.bounds.size.width,self.view.bounds.size.height);
    auto frame=[](beat4::Rect r) {return CGRectMake(r.x,r.y,r.w,r.h);};
    _logo.frame=frame(l.logo);
    _host.frame=frame(l.host);
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
    _pgLabel.font=Mono(l.transportsInHeader?9:11);
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
    [_bpmButton setTitle:bpm>=20?[NSString stringWithFormat:@"%.0f BPM",std::round(bpm)]:@"--- BPM" forState:UIControlStateNormal];
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
    NSInteger pg=[self.unit currentProgram];
    if(pg<0)return;
    if(gesture.state==UIGestureRecognizerStateBegan){
        self.bpmDragProgram=pg;
        double stored=[[self.unit currentSong][@"bpm"] doubleValue];
        double host=[[self.unit transportSnapshot][@"bpm"] doubleValue];
        self.bpmDragStart=std::round(beat4::validBPM(stored)?stored:(beat4::validBPM(host)?host:128));
        self.bpmDragOriginX=0;
    }
    if(pg!=self.bpmDragProgram)return;
    if(gesture.state==UIGestureRecognizerStateChanged ||
       gesture.state==UIGestureRecognizerStateEnded){
        // Absolute displacement, not accumulated deltas: no runaway or drift.
        CGFloat dx=[gesture translationInView:self.view].x-self.bpmDragOriginX;
        double target=std::clamp(self.bpmDragStart+std::round(dx/9.0),20.0,240.0);
        [_bpmButton setTitle:[NSString stringWithFormat:@"%.0f BPM",target] forState:UIControlStateNormal];
        if(gesture.state==UIGestureRecognizerStateEnded){
            [self.unit saveSongBPM:target];
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
    (void)link;
    NSDictionary *data=[self.unit transportSnapshot];self.canvas.snapshot=data;
    NSInteger pg=[data[@"pg"] integerValue];
    if(pg!=self.seenPG){self.seenPG=pg;[self refreshSong];}
    BOOL synced=[data[@"synced"] boolValue];
    BOOL moving=[data[@"moving"] boolValue];
    _host.text=synced?[NSString stringWithFormat:@"AUM %.1f %@ · v0.5.3",[data[@"bpm"] doubleValue],moving?@"▶":@"Ⅱ"] : (![data[@"hasRender"] boolValue]?@"AUM NO AUDIO · v0.5.3":@"AUM NO HOST · v0.5.3");
    BOOL enabled=[data[@"kickEnabled"] boolValue];
    [_kickButton setTitleColor:enabled?RGB(177,225,164):RGB(110,120,111) forState:UIControlStateNormal];
    if(!_levelSlider.tracking)_levelSlider.value=[data[@"kickLevel"] floatValue];
}
@end
