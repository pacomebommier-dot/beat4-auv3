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
@interface Beat4Button : UIButton @end
@implementation Beat4Button
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    (void)event;const CGFloat dx=MAX(0,(44-self.bounds.size.width)*.5);
    const CGFloat dy=MAX(0,(44-self.bounds.size.height)*.5);
    return CGRectContainsPoint(CGRectInset(self.bounds,-dx,-dy),point);
}
@end
@interface Beat4Canvas : UIView {
    beat4::Lights _lights;
    CFTimeInterval _lightTick;
}
@property(nonatomic,copy)NSDictionary<NSString*,NSNumber*> *snapshot;
@property(nonatomic,assign)CGRect lightBounds;
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
    [RGB(7,9,8) setFill];UIRectFill(rect);if(!self.showBars)return;
    const auto layout=beat4::layoutFor(self.bounds.size.width,self.bounds.size.height);
    CGContextRef ctx=UIGraphicsGetCurrentContext();if(!ctx)return;
    for(int i=0;i<4;++i){
        const CGFloat energy=_lights.energy(i);
        const CGRect r=CGRectMake(self.lightBounds.origin.x+i*(layout.barWidth+layout.barGap),
            self.lightBounds.origin.y,layout.barWidth,self.lightBounds.size.height);
        UIBezierPath *shape=[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:layout.corner];
        CGContextSaveGState(ctx);
        if(energy>.001)CGContextSetShadowWithColor(ctx,CGSizeZero,12*layout.scale,
            RGB(151,185,139,.35*energy).CGColor);
        [RGB(24,34,26) setFill];[shape fill];CGContextRestoreGState(ctx);
        if(energy>.001){
            // V2/R02 vertical phosphor gradient; energy comes exclusively from host-beat envelope.
            const CGFloat colors[]={.75,.86,.65,energy, .70,.82,.62,energy, .50,.63,.46,energy};
            const CGFloat stops[]={0,.52,1};CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
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

@interface Beat4ViewController ()
@property(nonatomic,strong)Beat4AudioUnit *unit;
@property(nonatomic,strong)Beat4Canvas *canvas;
@property(nonatomic,strong)CADisplayLink *clock;
@property(nonatomic,copy)NSDictionary *frameSnapshot;
@property(nonatomic,strong)UILabel *logo,*versionLabel,*host,*pgLabel,*subLabel,*levelLabel,*modeLabel,*pcModeLabel;
@property(nonatomic,strong)UIButton *kickButton,*noteButton,*songButton,*bpmButton;
@property(nonatomic,strong)UIButton *playButton,*queueButton,*saveButton;
@property(nonatomic,strong)UISegmentedControl *modeControl;
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
    self.seenPG=-999;self.editedPC=0;self.canvas.showBars=YES;
    _logo=[self makeLabel:@"BEAT//4" size:20 color:RGB(220,224,212)];
    _logo.font=Mono(20,UIFontWeightSemibold);
    _versionLabel=[self makeLabel:[NSString stringWithFormat:@"v%@",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.5.8"] size:8 color:RGB(122,145,121)];
    _modeLabel=[self makeLabel:@"TEMPO MODE" size:10 color:RGB(197,208,197)];
    _pcModeLabel=[self makeLabel:@"" size:10 color:RGB(132,157,136)];
    _host=[self makeLabel:@"AUM  •  WAIT" size:11 color:RGB(144,161,140)];_host.textAlignment=NSTextAlignmentRight;
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
    [_playButton addTarget:self action:@selector(toggleTransport:) forControlEvents:UIControlEventTouchUpInside];
    _playButton.accessibilityLabel=@"AUM PLAY/STOP (CC110/111 canal 16)";
    _pageRegion=[UIView new];[self.view addSubview:_pageRegion];
    for(NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionLeft),@(UISwipeGestureRecognizerDirectionRight)]){
        UISwipeGestureRecognizer *swipe=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipePage:)];
        swipe.direction=(UISwipeGestureRecognizerDirection)direction.unsignedIntegerValue;
        [_pageRegion addGestureRecognizer:swipe];
    }
    _pads=[NSMutableArray new];
    for(int i=0;i<32;++i){
        UIButton *pad=[UIButton buttonWithType:UIButtonTypeCustom];pad.tag=i;
        pad.titleLabel.font=Mono(15);pad.layer.cornerRadius=4;
        [pad addTarget:self action:@selector(selectPad:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *edit=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(editPadQueue:)];
        [pad addGestureRecognizer:edit];
        [_pageRegion addSubview:pad];[_pads addObject:pad];
    }
    _queueButton=[self makeButton:@"QUEUE —" size:10];
    [_queueButton addTarget:self action:@selector(editQueue:) forControlEvents:UIControlEventTouchUpInside];
    _modeControl=[[UISegmentedControl alloc]initWithItems:@[@"0",@"1",@"2"]];
    _modeControl.selectedSegmentIndex=[[self.unit transportSnapshot][@"globalMode"] integerValue];
    _modeControl.accessibilityLabel=@"MODE global";
    [_modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_modeControl];
    _saveButton=[self makeButton:@"SAVE" size:10];
    [_saveButton addTarget:self action:@selector(saveMode:) forControlEvents:UIControlEventTouchUpInside];
    [self refreshSong];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    const auto l=beat4::layoutFor(self.view.bounds.size.width,self.view.bounds.size.height);
    auto frame=[](beat4::Rect r){return CGRectMake(r.x,r.y,r.w,r.h);};
    _logo.frame=frame(l.logo);_logo.font=Mono(l.logoSize,UIFontWeightSemibold);
    _versionLabel.frame=frame(l.version);_versionLabel.font=Mono(l.versionSize);
    _host.frame=frame(l.host);_host.font=Mono(l.hostSize);_host.hidden=NO;
    _pgLabel.frame=frame(l.status);_pgLabel.font=Mono(l.transportsInHeader?12*l.scale:14*l.scale);
    self.canvas.lightBounds=frame(l.bars);[self.canvas setNeedsDisplay];
    _kickButton.frame=frame(l.kick);_kickButton.titleLabel.font=Mono(l.kickSize);
    _subLabel.frame=frame(l.subLabel);_subLabel.font=Mono(l.subSize);
    _noteButton.frame=frame(l.subValue);_noteButton.titleLabel.font=Mono(l.noteSize);
    _levelLabel.frame=frame(l.levelLabel);_levelLabel.font=Mono(l.levelSize);
    // Align actual font descenders to the same R02 lower typographic edge.
    if(!l.portrait){
        const CGFloat bottom=l.kick.y+l.kick.h;
        for(UILabel *label in @[_subLabel,_levelLabel]){
            CGRect f=label.frame;f.size.height=label.font.lineHeight;
            f.origin.y=bottom+label.font.descender-f.size.height;label.frame=f;
        }
        for(UIButton *button in @[_kickButton,_noteButton]){
            CGRect f=button.frame;f.size.height=button.titleLabel.font.lineHeight;
            f.origin.y=bottom+button.titleLabel.font.descender-f.size.height;button.frame=f;
        }
    }
    _levelSlider.frame=frame(l.levelSlider);
    _bpmButton.frame=frame(l.bpm);_bpmButton.titleLabel.font=Mono(l.bpmSize,UIFontWeightMedium);
    _songButton.frame=frame(l.song);_songButton.titleLabel.font=Mono(l.songSize,UIFontWeightMedium);
    _songButton.titleLabel.adjustsFontSizeToFitWidth=YES;_songButton.titleLabel.minimumScaleFactor=.5;
    _playButton.frame=frame(l.toggle);_playButton.titleLabel.font=Mono(24*l.scale);
    _pageRegion.frame=frame(l.bars);
    for(int i=0;i<32;++i)_pads[i].frame=frame(beat4::programPad({0,0,l.bars.w,l.bars.h},i));
    _queueButton.frame=frame(l.queue);
    _modeLabel.frame=frame(l.modeLabel);_modeLabel.font=Mono(l.modeSize);
    _modeControl.frame=frame(l.modeControl);
    _modeControl.selectedSegmentTintColor=RGB(190,234,178);
    [_modeControl setTitleTextAttributes:@{NSFontAttributeName:Mono(MAX(9.,l.modeSize)),NSForegroundColorAttributeName:RGB(228,235,220)} forState:UIControlStateNormal];
    [_modeControl setTitleTextAttributes:@{NSForegroundColorAttributeName:RGB(19,27,18)} forState:UIControlStateSelected];
    _saveButton.frame=frame(l.save);_saveButton.titleLabel.font=Mono(l.modeSize);
    _pcModeLabel.frame=frame(l.pcMode);_pcModeLabel.font=Mono(MAX(9.,l.modeSize-1));
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
- (void)refreshSong {
    NSDictionary *state=self.frameSnapshot ?: [self.unit transportSnapshot];
    NSInteger pg=[state[@"pg"] integerValue];
    NSDictionary *song=[self.unit songForProgram:pg];
    NSInteger selected=[state[@"selectedPC"] integerValue];
    NSString *active=pg<0?@"ACTIVE —":[NSString stringWithFormat:@"ACTIVE PC %02ld%@",(long)pg+1,[state[@"estimated"] boolValue]?@" (estimé)":@""];
    NSString *pending=selected<0?@"":[NSString stringWithFormat:@" · SELECTED %02ld%@",(long)selected+1,[state[@"uncertain"] boolValue]?@" PHASE ?":@""];
    NSString *saved=song[@"pcMode"] && [song[@"pcMode"] intValue]>=0?[NSString stringWithFormat:@" · PC MODE %@",song[@"pcMode"]]:@"";
    _pgLabel.text=[NSString stringWithFormat:@"%@%@",active,pending];
    _pcModeLabel.text=[saved stringByReplacingOccurrencesOfString:@" · " withString:@""];
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
- (void)modeChanged:(UISegmentedControl*)sender {[self.unit setGlobalMode:sender.selectedSegmentIndex];}
- (void)saveMode:(id)sender {(void)sender;[self.unit saveCurrentMode];[self refreshSong];}
- (void)swipePage:(UISwipeGestureRecognizer*)gesture {
    self.page=beat4::nextPage((int)self.page,gesture.direction==UISwipeGestureRecognizerDirectionLeft?1:-1);
    [self refreshPage];
}
- (void)selectPad:(UIButton*)sender {
    NSInteger pc=(self.page-1)*32+sender.tag;self.editedPC=pc;
    [self.unit selectProgram:pc];[self refreshPage];
}
- (void)editPadQueue:(UILongPressGestureRecognizer*)gesture {
    if(gesture.state!=UIGestureRecognizerStateBegan)return;
    self.editedPC=(self.page-1)*32+gesture.view.tag;[self editQueue:nil];
}
- (void)editQueue:(id)sender {
    (void)sender;const NSInteger pc=self.editedPC;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"QUEUE · SONG %02ld",(long)pc+1]
        message:@"Beats entiers. Vide = prochain BAR AUM. Appui long sur un pad pour éditer sans l’activer."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){
        t.keyboardType=UIKeyboardTypeNumberPad;int q=[[self.unit songForProgram:pc][@"queue"] intValue];
        t.text=q>0?[NSString stringWithFormat:@"%d",q]:@"";t.placeholder=@"—";
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    __weak Beat4ViewController *weakSelf=self;
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;NSString *v=a.textFields.firstObject.text ?: @"";
        NSScanner *scanner=[NSScanner scannerWithString:v];long long n=0;
        if(v.length && (![scanner scanLongLong:&n] || !scanner.isAtEnd || n<1 || n>65536))return;
        [weakSelf.unit saveQueue:(NSInteger)n program:pc];[weakSelf refreshPage];
    }]];[self presentViewController:a animated:YES completion:nil];
}
- (void)refreshPage {
    if(self.canvas.showBars!=(self.page==0)){self.canvas.showBars=self.page==0;[self.canvas setNeedsDisplay];}
    NSDictionary *state=self.frameSnapshot ?: [self.unit transportSnapshot];
    int active=[state[@"pg"] intValue],selected=[state[@"selectedPC"] intValue];
    for(int i=0;i<32;++i){
        UIButton *pad=_pads[i];pad.hidden=self.page==0;int pc=((int)self.page-1)*32+i;
        [pad setTitle:[NSString stringWithFormat:@"%02d",pc+1] forState:UIControlStateNormal];
        pad.backgroundColor=pc==active?RGB(240,240,235):pc==selected?RGB(135,135,135):RGB(25,29,26);
        [pad setTitleColor:pc==active||pc==selected?RGB(10,12,10):RGB(190,196,187) forState:UIControlStateNormal];
        pad.accessibilityLabel=[NSString stringWithFormat:@"SONG %02d %@",pc+1,pc==active?@"ACTIF":pc==selected?@"SÉLECTIONNÉ":@"ÉTEINT"];
    }
    _queueButton.hidden=self.page==0;
    int q=[[self.unit songForProgram:self.editedPC][@"queue"] intValue];
    [_queueButton setTitle:[NSString stringWithFormat:@"SONG %02ld · QUEUE %@",(long)self.editedPC+1,q>0?[NSString stringWithFormat:@"%d",q]:@"—"] forState:UIControlStateNormal];
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
    NSString *title=self.page==0?@"MÉTRONOME":self.page==1?@"PC 01–32":@"PC 33–64";
    _host.text=synced?[NSString stringWithFormat:@"%@ · %.1f",title,[data[@"bpm"] doubleValue]]:[NSString stringWithFormat:@"%@ · %@",title,[data[@"hasRender"] boolValue]?@"NO HOST":@"NO AUDIO"];
    [_playButton setTitle:moving?@"■":@"▶" forState:UIControlStateNormal];
    [self refreshSong];[self refreshPage];
    double target=[[self.unit currentSong][@"bpm"] doubleValue];
    [_bpmButton setTitleColor:beat4::validBPM(target)?(synced && std::abs(target-[data[@"bpm"] doubleValue])>.05?RGB(235,155,65):RGB(219,223,209)):RGB(110,120,111) forState:UIControlStateNormal];
    BOOL enabled=[data[@"kickEnabled"] boolValue];
    [_kickButton setTitleColor:enabled?RGB(177,225,164):RGB(110,120,111) forState:UIControlStateNormal];
    if(!_levelSlider.tracking)_levelSlider.value=[data[@"kickLevel"] floatValue];
    self.lastMoving=moving;self.lastSynced=synced;self.seenRevision=revision;
}
@end
