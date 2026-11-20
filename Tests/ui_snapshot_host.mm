#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../Beat4AU/Beat4ViewController.h"
#import "../Beat4AU/Beat4AudioUnit.h"
#include <cassert>
#include <cmath>
#include "../Beat4AU/Beat4Songs.hpp"
#import <QuartzCore/QuartzCore.h>

@interface Beat4ViewController (SnapshotTest)
- (void)updateDisplay:(CADisplayLink *)link;
- (UIMenu *)padColorMenuForProgram:(NSInteger)pc;
@end

@interface SnapshotApp : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong)UIWindow *window;
@end
@implementation SnapshotApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
 (void)app;(void)options;
 @try {
  NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
  [NSUserDefaults.standardUserDefaults removePersistentDomainForName:bundle];
  Beat4ViewController *vc=[Beat4ViewController new];NSError *error=nil;
  AudioComponentDescription desc={kAudioUnitType_MusicDevice,'bt04','B4MT',0,0};
  Beat4AudioUnit *unit=(Beat4AudioUnit*)[vc createAudioUnitWithComponentDescription:desc error:&error];
  assert(unit && !error);
  __block BOOL moving=NO;__block double beat=0,hostBPM=128;
  unit.musicalContextBlock=^BOOL(double *tempo,double *num,NSInteger *den,double *position,NSInteger *offset,double *downbeat){
   if(tempo)*tempo=hostBPM;if(num)*num=4;if(den)*den=4;if(position)*position=beat;
   if(offset)*offset=0;if(downbeat)*downbeat=std::floor(beat/4)*4;return YES;
  };
  unit.transportStateBlock=^BOOL(AUHostTransportStateFlags *flags,double *sample,double *start,double *end){
   if(flags)*flags=moving?AUHostTransportStateMoving:(AUHostTransportStateFlags)0;
   if(sample)*sample=beat*48000*60/128;if(start)*start=0;if(end)*end=0;return YES;
  };
  NSMutableArray *messages=[NSMutableArray new],*relayMessages=[NSMutableArray new];
  unit.MIDIOutputEventBlock=^OSStatus(AUEventSampleTime time,uint8_t cable,NSInteger length,const uint8_t *bytes){
   NSMutableArray *data=[NSMutableArray new];for(NSInteger i=0;i<length;++i)[data addObject:@(bytes[i])];
   [(cable==2?relayMessages:messages) addObject:@{@"sample":@(time),@"cable":@(cable),@"bytes":data}];
   return noErr;
  };
  assert([unit allocateRenderResourcesAndReturnError:&error] && !error);
  AUInternalRenderBlock render=unit.internalRenderBlock;
  __block const AURenderEvent *input=nullptr;
  void (^tick)(void)=^{
   float samples[256]={};AudioBufferList buffers{};buffers.mNumberBuffers=1;
   buffers.mBuffers[0]={2,sizeof(samples),samples};
   AudioTimeStamp stamp{};stamp.mFlags=kAudioTimeStampSampleTimeValid;stamp.mSampleTime=beat*48000*60/128;
   AudioUnitRenderActionFlags flags=0;
   assert(render(&flags,&stamp,128,0,&buffers,input,nil)==noErr);
  };
  [unit selectProgram:7];tick();assert(unit.currentProgram==7 && messages.count==1);
  NSArray *expectedPC=@[@207,@7];
  assert([messages[0][@"cable"] intValue]==1 && [messages[0][@"bytes"] isEqual:expectedPC]);
  [unit saveSongBPM:117 program:6];
  assert([[[unit songForProgram:6] objectForKey:@"bpm"] doubleValue]==117);
  assert([[[unit songForProgram:7] objectForKey:@"bpm"] doubleValue]==0);
  [unit saveSongTitle:@"R10 NATIVE TEST"];[unit saveSongBPM:135];[unit saveSongSubNote:5];
  [unit previewRamp:3 enabled:YES program:7 apply:NO];
  [unit saveRelayEnabled:YES bars:5 fade:2 program:7];
  assert([unit relayForProgram:7][@"enabled"]&&[[unit relayForProgram:7][@"bars"] intValue]==5);
  assert([[unit rampForProgram:7][@"temporary"] boolValue]);
  assert(![unit songForProgram:7][@"rampBars"]||[[unit songForProgram:7][@"rampBars"] intValue]!=3);
  auto relayState=unit.fullStateForDocument;Beat4AudioUnit *relayRestored=[[Beat4AudioUnit alloc]initWithComponentDescription:desc options:0 error:&error];
  assert(relayRestored&&!error);relayRestored.fullStateForDocument=relayState;
  assert([[relayRestored relayForProgram:7][@"bars"] intValue]==5&&[[relayRestored relayForProgram:7][@"fade"] intValue]==2);
  [unit saveRelayEnabled:NO bars:5 fade:2 program:7];
  assert(![[unit relayForProgram:7][@"enabled"] boolValue]&&[[unit relayForProgram:7][@"fade"] intValue]==2);
  // STOP + PCH loads the next song without emitting a RELAY transition.
  const NSUInteger stoppedRelayCount=relayMessages.count;
  [unit selectProgram:6];tick();[unit selectProgram:7];tick();
  for(NSUInteger n=stoppedRelayCount;n<relayMessages.count;++n)assert([relayMessages[n][@"bytes"][6] intValue]==1);
  assert([unit.transportSnapshot[@"relayTransitions"] intValue]==0);
  // Existing assertions concern only the unchanged legacy outputs.
  [messages removeObjectsInRange:NSMakeRange(1,messages.count-1)];
  [unit setCycleSteps:32];[unit saveCurrentCycle];
  moving=YES;beat=1;tick();[unit selectProgram:39];tick();
  assert([unit.transportSnapshot[@"selectedPC"] intValue]==39 && messages.count==1);
  self.window=[[UIWindow alloc]initWithFrame:CGRectMake(0,0,1024,768)];self.window.rootViewController=vc;
  [self.window makeKeyAndVisible];
  NSString *directory=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/R10"];
  [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
  assert(!error);
  const CGSize sizes[]={{720,400},{667,375},{1024,768},{390,844}};
  for(CGSize size:sizes){
   for(int page=0;page<3;++page){
    [vc setValue:@(page) forKey:@"page"];
    vc.view.frame=CGRectMake(0,0,size.width,size.height);
    [vc.view setNeedsLayout];[vc.view layoutIfNeeded];
    [vc updateDisplay:nil];
    UIButton *relayToggle=[vc valueForKey:@"relayToggle"],*relayFade=[vc valueForKey:@"relayFade"],*relayDuration=[vc valueForKey:@"relayDuration"];
    assert(!relayFade.enabled&&[relayDuration.currentTitle isEqual:@"5"]);
    [relayToggle sendActionsForControlEvents:UIControlEventTouchUpInside];[vc updateDisplay:nil];assert(relayFade.enabled);
    [relayToggle sendActionsForControlEvents:UIControlEventTouchUpInside];[vc updateDisplay:nil];assert(!relayFade.enabled);
    assert(CGRectGetMaxX(relayFade.frame)<=size.width+0.1&&CGRectGetMaxY(relayFade.frame)<=size.height);
    UISlider *slider=[vc valueForKey:@"levelSlider"];
    CGFloat trackCenter=CGRectGetMidY(slider.frame);
    auto capCenter=[](UIView *v,UIFont *font){
      return CGRectGetMidY(v.frame)+(font.ascender+font.descender-font.capHeight)/2;
    };
    UIButton *kick=[vc valueForKey:@"kickButton"],*note=[vc valueForKey:@"noteButton"];
    UILabel *sub=[vc valueForKey:@"subLabel"],*level=[vc valueForKey:@"levelLabel"];
    CGFloat textCenter=capCenter(kick,kick.titleLabel.font);
    assert(std::abs(capCenter(sub,sub.font)-textCenter)<.01);
    assert(std::abs(capCenter(note,note.titleLabel.font)-textCenter)<.01);
    assert(std::abs(capCenter(level,level.font)-trackCenter)<.01);
    if(size.width>size.height)assert(std::abs(textCenter-trackCenter)<.01);
    UILabel *title=[vc valueForKey:@"host"];
    CGPoint target=CGPointMake(CGRectGetMidX(title.bounds),-8);
    assert([vc.view hitTest:[title convertPoint:target toView:vc.view] withEvent:nil]==title);
    NSArray<UIButton*> *pads=[vc valueForKey:@"pads"];assert(pads.count==32);
    UILabel *header=[vc valueForKey:@"pgLabel"];
    assert([header.text containsString:@"ACTIVE PC 08"] && [header.text containsString:@"SELECTED 40"]);
    if(page>0){
     for(UIButton *pad in pads){
      int pc=(page-1)*32+(int)pad.tag;
      assert(!pad.hidden);
      if(pc==7){assert([pad.accessibilityLabel containsString:@"ACTIF"]);assert([pad.currentTitle isEqual:@"R10 NATIVE TEST"]);}
      else assert(([pad.currentTitle isEqual:[NSString stringWithFormat:@"%02d",pc+1]]));
      if(pc==39)assert([pad.accessibilityLabel containsString:@"EN ATTENTE"]);
      CGFloat r=0,g=0,b=0,a=0;assert([pad.backgroundColor getRed:&r green:&g blue:&b alpha:&a]);
      if(pc==7)assert(std::abs(r-60./255)<.01&&std::abs(g-145./255)<.01);
      else assert(r<.15&&g<.15);
     }
    }
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=1;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:size format:format];
    UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[vc.view.layer renderInContext:context.CGContext];}];
    NSString *file=[NSString stringWithFormat:@"%@/%.0fx%.0f_page%d.png",directory,size.width,size.height,page];
    assert([UIImagePNGRepresentation(image) writeToFile:file atomically:YES]);
   }
  }
  // FIX-03/04: title cycle is visual only; eight fixed mini-pads on title row.
  [vc setValue:@0 forKey:@"page"];[vc updateDisplay:nil];
  NSDictionary *before=unit.transportSnapshot;
  UILabel *viewTitle=[vc valueForKey:@"host"];
  for(int i=0;i<3;++i){
   UITapGestureRecognizer *tap=(UITapGestureRecognizer*)viewTitle.gestureRecognizers.firstObject;
   assert([viewTitle pointInside:CGPointMake(CGRectGetWidth(viewTitle.bounds)/2,-8) withEvent:nil]);
   [vc performSelector:@selector(nextView:) withObject:tap];
   assert([viewTitle.text isEqualToString:(i==0?@"PC 01–32":i==1?@"PC 33–64":@"MÉTRONOME")]);
   assert([[vc valueForKey:@"canvas"] valueForKey:@"showBars"] &&
          [[[vc valueForKey:@"canvas"] valueForKey:@"showBars"] boolValue]==(i==2));
  }
  assert([[vc valueForKey:@"page"] intValue]==0);
  assert([unit.transportSnapshot[@"pg"] isEqual:before[@"pg"]]);
  assert([unit.transportSnapshot[@"selectedPC"] isEqual:before[@"selectedPC"]]);
  assert([unit.transportSnapshot[@"moving"] isEqual:before[@"moving"]]);
  NSArray<UIButton*> *mini=[vc valueForKey:@"setPads"];assert(mini.count==10);
  for(UIButton *pad in mini){
   assert(!pad.hidden && pad.frame.size.height>=viewTitle.font.capHeight);
   assert(CGRectGetMinX(pad.frame)>=CGRectGetMaxX(viewTitle.frame));
  }
  // The last two SET positions must be reachable and name the assigned PC,
  // even while a different PC is active and another PC is queued.
  UIButton *editor=[vc valueForKey:@"setEditButton"];
  UIButton *songControl=[vc valueForKey:@"songButton"];
  [editor sendActionsForControlEvents:UIControlEventTouchUpInside];
  NSArray<UIButton*> *programPads=[vc valueForKey:@"pads"];
  for(int index=8;index<10;++index){
   UIButton *pad=mini[index];
   CGPoint center=[pad convertPoint:CGPointMake(CGRectGetMidX(pad.bounds),CGRectGetMidY(pad.bounds)) toView:vc.view];
   assert([vc.view hitTest:center withEvent:nil]==pad);
   [pad sendActionsForControlEvents:UIControlEventTouchUpInside];
   [programPads[index+6] sendActionsForControlEvents:UIControlEventTouchUpInside];
   tick();[vc updateDisplay:nil];
   NSArray *assigned=unit.setSnapshot[@"slots"];
   assert([assigned[index] intValue]==index+6);
   assert([songControl.currentTitle isEqualToString:@"UNKNOWN"]);
   assert(unit.currentProgram==7 && [unit.transportSnapshot[@"selectedPC"] intValue]==39);
   assert(messages.count==1);
   NSString *name=[NSString stringWithFormat:@"Recette %d",index+1];
   [unit saveSongTitle:name program:index+6];[vc updateDisplay:nil];
   assert([songControl.currentTitle isEqualToString:name]);
   assert([unit.currentSong[@"title"] isEqualToString:@"R10 NATIVE TEST"]);
   [unit saveSongTitle:@"" program:index+6];
   [unit assignSetPosition:index program:-1];tick();
  }
  [editor sendActionsForControlEvents:UIControlEventTouchUpInside];
  [vc setValue:@0 forKey:@"page"];[vc updateDisplay:nil];
  AURenderEvent event{};event.head.eventType=AURenderEventMIDI;event.head.eventSampleTime=AUEventSampleTimeImmediate;
  event.MIDI.length=2;event.MIDI.data[0]=0xCF;event.MIDI.data[1]=103;input=&event;tick();
  assert(unit.currentProgram==7 && ![unit.transportSnapshot[@"uncertain"] boolValue] && messages.count==1);
  input=nullptr;beat=3.99;tick();assert(unit.currentProgram==7);
  beat=4;tick();assert(unit.currentProgram==7 && messages.count==1);
  beat=8;tick();assert(unit.currentProgram==39 && messages.count==1);
  input=&event;
  event.MIDI.data[1]=39;tick();assert(unit.currentProgram==39 && messages.count==1);input=nullptr;
  [unit requestTransportToggle];tick();tick();
  NSArray *stopPress=@[@191,@111,@127],*stopRelease=@[@191,@111,@0];
  assert(messages.count==3 && [messages[1][@"bytes"] isEqual:stopPress] && [messages[2][@"bytes"] isEqual:stopRelease]);
  moving=NO;[unit requestTransportToggle];tick();tick();
  NSArray *playPress=@[@191,@110,@127],*playRelease=@[@191,@110,@0];
  assert(messages.count==5 && [messages[3][@"bytes"] isEqual:playPress] && [messages[4][@"bytes"] isEqual:playRelease]);
  // Stored BPMs use the full range, including values skipped by CC118.
  NSData *named=[@"{\"format\":\"BEAT4_CONFIG\",\"version\":1,\"songs\":[{\"song\":1,\"name\":\"A\"},{\"song\":2,\"name\":\"B\"},{\"song\":3,\"name\":\"C\"},{\"song\":12,\"name\":\"RAMP\",\"rampBars\":1}]}" dataUsingEncoding:NSUTF8StringEncoding];
  assert([unit importConfigurationData:named error:&error]);
  for(int pc=0;pc<3;++pc){
   const int bpm=pc==0?20:pc==1?97:240;
   const NSUInteger before=messages.count;
   [unit saveSongBPM:bpm program:pc];tick();assert(messages.count==before);
   assert([[unit songForProgram:pc][@"bpm"] intValue]==bpm);
   [unit selectProgram:pc];tick();assert(messages.count==before+2);
   assert([messages[before][@"cable"] intValue]==1);
   assert(([messages[before][@"bytes"] isEqual:@[@207,@(pc)]]));
   const int bend=beat4::tempoPitchBend14(bpm);
   assert([messages[before+1][@"cable"] intValue]==0);
   assert(([messages[before+1][@"bytes"] isEqual:@[@238,@(bend&127),@(bend>>7)]]));
   tick();assert(messages.count==before+2);
  }
  const NSUInteger beforeUnknown=messages.count;
  [unit selectProgram:3];tick();assert(messages.count==beforeUnknown+1); // PC only
  // Real single-byte render events from Circuit. Host changes are applied
  // separately, reproducing the delay between a CC request and its observation.
  moving=YES;tick(); // acknowledge the preceding local START
  const NSUInteger beforeTransport=messages.count;
  event.MIDI.length=1;event.MIDI.data[0]=0xFC;input=&event;
  tick();tick();tick(); // duplicate STOP before acknowledgement: one press/release
  assert(messages.count==beforeTransport+2);
  assert([messages[beforeTransport][@"cable"] intValue]==0);
  assert([messages[beforeTransport][@"bytes"] isEqual:stopPress]);
  assert([messages[beforeTransport+1][@"bytes"] isEqual:stopRelease]);
  moving=NO;tick();tick();assert(messages.count==beforeTransport+2);
  event.MIDI.data[0]=0xFA;tick();tick();tick();
  assert(messages.count==beforeTransport+4);
  assert([messages[beforeTransport+2][@"bytes"] isEqual:playPress]);
  assert([messages[beforeTransport+3][@"bytes"] isEqual:playRelease]);
  moving=YES;tick();tick(); // simulated Circuit echo after AUM START
  event.MIDI.data[0]=0xFB;tick(); // continue while already playing
  event.MIDI.data[0]=0xF8;for(int n=0;n<100;++n)tick();
  assert(messages.count==beforeTransport+4); // no clock/transport echo on either cable
  input=nullptr;
  NSDictionary *diagnostic=unit.transportSnapshot;
  assert([diagnostic[@"receivedStart"] intValue]==6 && [diagnostic[@"receivedStop"] intValue]==5);
  assert([diagnostic[@"sentTransport"] intValue]==4 && [diagnostic[@"lastRealtime"] intValue]==0xFB);
  assert([diagnostic[@"awaitingTransport"] intValue]==-1);
  for(NSDictionary *message in messages){
   NSArray *bytes=message[@"bytes"];
   if(([bytes[0] intValue]&0xF0)==0xE0)assert([bytes[0] intValue]==0xEE&&[message[@"cable"] intValue]==0); // no pitch bend on either output
  }
  // Native AU regression: selection starts tempo during queue and SAVE edits ACTIVE.
  input=nullptr;moving=NO;tick();[unit selectProgram:10];tick();
  [unit saveSongBPM:148 program:11];
  moving=YES;beat=33;tick();[unit selectProgram:11];tick();
  assert(unit.currentProgram==10 && [unit.transportSnapshot[@"selectedPC"] intValue]==11);
  [unit setCycleSteps:32];[unit saveCurrentCycle];
  assert([[unit songForProgram:10][@"steps"] intValue]==32);
  assert(![unit songForProgram:11][@"steps"] || [[unit songForProgram:11][@"steps"] intValue]==16);
  const NSUInteger rampBefore=messages.count;beat=35;tick();
  assert(messages.count==rampBefore && unit.currentProgram==10);
  beat=36;tick();assert(unit.currentProgram==11); // queued under active default16 before SAVE
  assert(messages.count==rampBefore+2);
  beat=38;tick();
  const int middle=beat4::tempoPitchBend14(141.75);
  assert(([messages.lastObject[@"bytes"] isEqual:@[@238,@(middle&127),@(middle>>7)]]));
  beat=40;tick();const int target=beat4::tempoPitchBend14(148);
  assert(([messages.lastObject[@"bytes"] isEqual:@[@238,@(target&127),@(target>>7)]]));
  beat=41;tick();
  [unit selectProgram:12];tick();[unit setCycleSteps:16];[unit saveCurrentCycle];
  assert([[unit songForProgram:11][@"steps"] intValue]==16);
  beat=44;tick();assert(unit.currentProgram==12);
  // Native selector really exposes16/32, never the obsolete0/1/2.
  [vc updateDisplay:nil];UISegmentedControl *cycles=[vc valueForKey:@"modeControl"];
  assert(cycles.numberOfSegments==2 && [[cycles titleForSegmentAtIndex:0] isEqual:@"16"] && [[cycles titleForSegmentAtIndex:1] isEqual:@"32"]);
  assert(cycles.selectedSegmentIndex==0);
  moving=NO;tick();[unit selectProgram:10];tick();[vc updateDisplay:nil];
  assert(cycles.selectedSegmentIndex==1); // recall explicit32 when returning to the active project

  // SET AU path: stopped PC/BPM before START, repeated NEXT, replacement and STOP.
  moving=NO;beat=0;tick();
  [unit assignSetPosition:1 program:0];[unit assignSetPosition:3 program:1];
  [unit assignSetPosition:5 program:0];[unit assignSetPosition:6 program:2];
  [unit setEnabled:YES];[unit selectSetPosition:1];tick();
  NSUInteger setBefore=messages.count;
  [unit requestPlayGestureLong:NO];tick();tick();
  assert(unit.currentProgram==0 && [unit.setSnapshot[@"cursor"] intValue]==1);
  assert(messages.count==setBefore+2);
  assert([messages[setBefore][@"bytes"] isEqual:playPress]);
  vc.view.frame=CGRectMake(0,0,1024,768);[vc.view setNeedsLayout];[vc.view layoutIfNeeded];[vc updateDisplay:nil];
  UIGraphicsImageRenderer *setRenderer=[[UIGraphicsImageRenderer alloc]initWithSize:vc.view.bounds.size];
  UIImage *setImage=[setRenderer imageWithActions:^(UIGraphicsImageRendererContext *context){[vc.view.layer renderInContext:context.CGContext];}];
  assert([UIImagePNGRepresentation(setImage) writeToFile:[directory stringByAppendingPathComponent:@"SET_ON_1024x768.png"] atomically:YES]);
  for(UIButton *pad in mini)assert(!pad.hidden);
  moving=YES;beat=1;tick();
  setBefore=messages.count;
  [unit requestPlayGestureLong:NO];tick();
  [unit requestPlayGestureLong:NO];tick();
  assert([unit.transportSnapshot[@"selectedPC"] intValue]==0);
  assert([unit.setSnapshot[@"cursor"] intValue]==1);
  for(NSUInteger i=setBefore;i<messages.count;++i)
   assert(![messages[i][@"bytes"] isEqual:playPress]);
  // External queued PC replaces pending SET and does not move cursor.
  event.MIDI.length=2;event.MIDI.data[0]=0xCF;event.MIDI.data[1]=66;input=&event;tick();input=nullptr;
  assert([unit.transportSnapshot[@"selectedPC"] intValue]==2 && [unit.setSnapshot[@"cursor"] intValue]==1);
  [unit requestPlayGestureLong:NO];tick();assert([unit.transportSnapshot[@"selectedPC"] intValue]==1);
  beat=3.99;tick();assert(unit.currentProgram==0);
  beat=4;tick();assert(unit.currentProgram==1 && [unit.setSnapshot[@"cursor"] intValue]==3);
  [unit requestPlayGestureLong:NO];tick();[unit requestPlayGestureLong:YES];tick();tick();
  assert([unit.transportSnapshot[@"selectedPC"] intValue]==-1);
  beat=8;tick();assert(unit.currentProgram==1);
  // Independent external-request cable must use the same quantized queue.
  [unit selectSetPosition:3];tick();
  event.MIDI.length=2;event.MIDI.cable=1;event.MIDI.data[0]=0xCF;event.MIDI.data[1]=2;input=&event;
  setBefore=messages.count;tick();input=nullptr;event.MIDI.cable=0;
  assert(unit.currentProgram==1 && [unit.transportSnapshot[@"selectedPC"] intValue]==2);
  assert([unit.setSnapshot[@"cursor"] intValue]==3);
  assert(messages.count==setBefore);
  beat=12;tick();assert(unit.currentProgram==2);
  assert([messages[setBefore][@"bytes"] isEqual:(@[@207,@2])]);
  // RESET from an intermediate pad: immediate published cursor + visible marker,
  // no transport/PC output, both ON and OFF; sparse first slot is index 1.
  for(NSNumber *enabled in @[@YES,@NO]){
   [unit setEnabled:enabled.boolValue];[unit selectSetPosition:3];tick();
   NSUInteger count=messages.count;
   NSInteger active=unit.currentProgram,queued=[unit.transportSnapshot[@"selectedPC"] integerValue];
   [unit resetSetCache];tick();[vc updateDisplay:nil];
   assert([unit.setSnapshot[@"cursor"] intValue]==1);
   assert(unit.currentProgram==active && [unit.transportSnapshot[@"selectedPC"] integerValue]==queued);
   assert(messages.count==count);
   assert([mini[1].accessibilityLabel containsString:@"curseur"]);
   assert(![mini[3].accessibilityLabel containsString:@"curseur"]);
  }
  [unit setEnabled:YES];tick();
  // RESET exactly at terminal boundary: queue first then reset -> first on PLAY.
  [unit selectSetPosition:6];tick();beat=16;[unit resetSetCache];tick();
  assert(unit.currentProgram==2 && [unit.setSnapshot[@"cursor"] intValue]==1);
  [unit resetSetCache];[unit requestPlayGestureLong:NO];tick();assert([unit.transportSnapshot[@"selectedPC"] intValue]==0);
  [unit setEnabled:NO];tick();assert([unit.transportSnapshot[@"selectedPC"] intValue]==0);
  for(int i=0;i<beat4::kSetCount;++i)[unit assignSetPosition:i program:-1];tick();
  assert(![unit.setSnapshot[@"on"] boolValue] && [unit.transportSnapshot[@"selectedPC"] intValue]==0);
  beat=20;tick();assert(unit.currentProgram==0);

  // SET ON starts the existing patch without a tempo or program command.
  moving=NO;tick();[unit assignSetPosition:0 program:1];[unit setEnabled:YES];tick();
  // Accessible activation has no preceding TouchDown and still requests short PLAY.
  UIButton *playControl=[vc valueForKey:@"playButton"];
  [playControl sendActionsForControlEvents:UIControlEventTouchUpInside];tick();
  assert([messages.lastObject[@"bytes"] isEqual:playPress]);
  // Long STOP must override a START not yet acknowledged by the host.
  setBefore=messages.count;[unit requestPlayGestureLong:YES];tick();tick();tick();
  BOOL foundStop=NO;for(NSUInteger i=setBefore;i<messages.count;++i)
   if([messages[i][@"bytes"] isEqual:stopPress])foundStop=YES;
  assert(foundStop && !moving);

  // Real XONE byte shape from the archived integration, not a CC assumption.
  moving=YES;tick();[unit requestPlayGestureLong:NO];tick();
  event.MIDI.length=3;event.MIDI.data[0]=0x9E;event.MIDI.data[1]=12;event.MIDI.data[2]=127;input=&event;
  setBefore=messages.count;tick();input=nullptr;
  assert(messages.count==setBefore); // no NEXT at press
  for(int i=0;i<210;++i)tick();
  event.MIDI.data[2]=0;input=&event;tick();input=nullptr;tick();
  assert([unit.transportSnapshot[@"selectedPC"] intValue]==-1);
  assert([messages[messages.count-2][@"bytes"] isEqual:stopPress]);
  moving=NO;tick();event.MIDI.data[2]=127;input=&event;setBefore=messages.count;tick();
  assert(messages.count==setBefore);
  event.MIDI.data[0]=0x8E;event.MIDI.data[2]=0;tick();input=nullptr;tick();
  assert([messages[messages.count-2][@"bytes"] isEqual:playPress]);
  // Autosave payload restores configuration and cursor, never queue or transport.
  [unit performSelector:@selector(persistSetSnapshot)];
  Beat4AudioUnit *restored=[[Beat4AudioUnit alloc]initWithComponentDescription:desc options:0 error:&error];
  assert([restored.setSnapshot[@"slots"] isEqual:unit.setSnapshot[@"slots"]]);
  assert([restored.setSnapshot[@"cursor"] isEqual:unit.setSnapshot[@"cursor"]]);
  assert(![restored.setSnapshot[@"on"] boolValue]);
  assert([restored.transportSnapshot[@"selectedPC"] intValue]==-1 && ![restored.transportSnapshot[@"moving"] boolValue]);

  // Portable bank + SET: same API as the native JSON picker and AU state.
  error=nil;
  Beat4AudioUnit *bank=[[Beat4AudioUnit alloc]initWithComponentDescription:desc options:0 error:&error];
  assert(bank&&!error);
  NSDictionary *payload=@{@"format":@"BEAT4_CONFIG",@"version":@1,
    @"songs":@[@{@"song":@1,@"name":@"PORTABLE",@"bpm":@137,@"sub":@"Do#",@"steps":@32},@{@"song":@64,@"bpm":@240,@"sub":@"Ré"}],
    @"set":@{@"slots":@[@1,[NSNull null],@64,[NSNull null],[NSNull null],[NSNull null],[NSNull null],[NSNull null]],@"on":@YES}};
  NSData *config=[NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
  NSDictionary *summary=[bank previewConfigurationData:config error:&error];
  assert([summary[@"songs"] intValue]==2&&[summary[@"set"] boolValue]);
  assert([bank importConfigurationData:config error:&error]&&!error);
  assert([[bank songForProgram:0][@"title"] isEqual:@"PORTABLE"]&&[[bank songForProgram:0][@"sub"] intValue]==1);
  assert([[bank songForProgram:63][@"bpm"] intValue]==240&&[[bank songForProgram:63][@"sub"] intValue]==2);
  NSDictionary *portable=bank.fullStateForDocument;
  assert([portable[@"BEAT4ConfigurationJSON"] isKindOfClass:NSData.class]);
  // AU state must remain a valid property list (JSON nulls live inside NSData).
  assert([NSPropertyListSerialization dataWithPropertyList:portable format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error]);
  Beat4AudioUnit *bankRestored=[[Beat4AudioUnit alloc]initWithComponentDescription:desc options:0 error:&error];
  NSData *extra=[@"{\"format\":\"BEAT4_CONFIG\",\"version\":1,\"songs\":[{\"song\":61,\"name\":\"ONLY_LOCAL\"}]}" dataUsingEncoding:NSUTF8StringEncoding];
  assert([bankRestored importConfigurationData:extra error:&error]);
  bankRestored.fullStateForDocument=portable;
  assert(![[bankRestored songForProgram:60][@"title"] isEqual:@"ONLY_LOCAL"]);
  assert(![bankRestored.setSnapshot[@"on"] boolValue]);
  assert([bankRestored.setSnapshot[@"cursor"] intValue]==0&&[bankRestored.setSnapshot[@"slots"][2] intValue]==63);
  // Partial import keeps fields and songs absent from the file.
  NSData *partial=[@"{\"format\":\"BEAT4_CONFIG\",\"version\":1,\"songs\":[{\"song\":1,\"name\":\"RENAMED\"}]}" dataUsingEncoding:NSUTF8StringEncoding];
  assert([bankRestored importConfigurationData:partial error:&error]);
  assert([[bankRestored songForProgram:0][@"bpm"] intValue]==137&&[[bankRestored songForProgram:0][@"steps"] intValue]==32);
  assert([[bankRestored songForProgram:63][@"bpm"] intValue]==240);
  NSData *beforeBad=[bankRestored exportConfigurationData:&error];
  error=nil;assert(![bankRestored importConfigurationData:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:&error]&&error);
  error=nil;assert([[bankRestored exportConfigurationData:&error] isEqual:beforeBad]);
  // Restore before rendering, then render: no PC, START or transport restored.
  NSUInteger midiBefore=messages.count;
  bankRestored.MIDIOutputEventBlock=unit.MIDIOutputEventBlock;
  assert([bankRestored allocateRenderResourcesAndReturnError:&error]);
  AUInternalRenderBlock bankRender=bankRestored.internalRenderBlock;
  float bankSamples[256]={};AudioBufferList bankBuffers{};bankBuffers.mNumberBuffers=1;bankBuffers.mBuffers[0]={2,sizeof(bankSamples),bankSamples};
  AudioTimeStamp bankStamp{};bankStamp.mFlags=kAudioTimeStampSampleTimeValid;OSStatus bankStatus=0;
  AudioUnitRenderActionFlags bankFlags=0;
  bankStatus=bankRender(&bankFlags,&bankStamp,128,0,&bankBuffers,nullptr,nil);assert(bankStatus==noErr);
  assert(messages.count==midiBefore&&bankRestored.currentProgram==-1&&[bankRestored.transportSnapshot[@"selectedPC"] intValue]==-1);
  assert([bankRestored.setSnapshot[@"cursor"] intValue]==0&&![bankRestored.setSnapshot[@"on"] boolValue]);
  [bankRestored deallocateRenderResources];
  // Name-only and note-only configuration also mark PC pads; musical colors win.
  NSData *colorData=[@"{\"format\":\"BEAT4_CONFIG\",\"version\":1,\"songs\":[{\"song\":30,\"name\":\"NAMED\"},{\"song\":31,\"sub\":\"C\"}]}" dataUsingEncoding:NSUTF8StringEncoding];
  assert([unit importConfigurationData:colorData error:&error]);
  [vc setValue:@1 forKey:@"page"];[vc updateDisplay:nil];
  NSArray *grid=[vc valueForKey:@"pads"];
  assert([[(UIButton*)grid[29] currentTitle] isEqual:@"NAMED"]);
  assert([[(UIButton*)grid[30] currentTitle] isEqual:@"31"]);
  [unit savePadColor:@"orange" program:29];[vc updateDisplay:nil];
  CGFloat r=0,g=0,b=0,a=0;[[(UIButton*)grid[29] backgroundColor] getRed:&r green:&g blue:&b alpha:&a];
  assert(std::abs(r-232./255)<.01);
  UIMenu *colorMenu=[vc padColorMenuForProgram:29];
  assert(colorMenu.children.count==10);
  for(NSUInteger i=0;i<8;++i){
    UIAction *action=(UIAction *)colorMenu.children[i];
    assert(action.image!=nil && action.state==(i==7?UIMenuElementStateOn:UIMenuElementStateOff));
  }
  UIButton *bpmControl=[vc valueForKey:@"bpmButton"];
  [vc setValue:@YES forKey:@"bpmDragging"];
  [vc setValue:@(unit.currentProgram) forKey:@"bpmDragProgram"];
  [vc setValue:@128 forKey:@"bpmDragTarget"];
  hostBPM=128.4;tick();[vc updateDisplay:nil];
  assert([[(UILabel*)[vc valueForKey:@"hostBPM"] text] isEqual:@"HOST 128 BPM"]);
  assert([bpmControl.currentTitleColor isEqual:UIColor.whiteColor]);
  [vc setValue:@129 forKey:@"bpmDragTarget"];
  [vc updateDisplay:nil];
  assert(![bpmControl.currentTitleColor isEqual:UIColor.whiteColor]);
  [vc setValue:@NO forKey:@"bpmDragging"];
  hostBPM=128;tick();

  [vc performSelector:@selector(showConfigurationMenu:) withObject:nil];
  UIAlertController *menu=(UIAlertController*)vc.presentedViewController;
  assert([menu isKindOfClass:UIAlertController.class]&&menu.actions.count==4);
  assert([menu.actions[0].title containsString:@"Importer"]&&[menu.actions[1].title containsString:@"Exporter"]);
  [vc dismissViewControllerAnimated:NO completion:nil];
  for(NSDictionary *message in messages){
   NSArray *bytes=message[@"bytes"];
   assert(!([bytes[0] intValue]==0xBE&&bytes.count>1&&[bytes[1] intValue]==118));
   if(([bytes[0] intValue]&0xF0)==0xE0)assert([bytes[0] intValue]==0xEE&&[message[@"cable"] intValue]==0);
  }
  // ON and SAVE can both occur before the render thread sees the command.
  moving=NO;tick();[unit selectProgram:0];tick();
  [unit saveSongBPM:148 program:0];
  moving=YES;beat+=4;tick();
  [unit previewRamp:1 enabled:YES program:0 apply:YES];
  [unit saveRampForProgram:0];
  NSDictionary *savedRamp=[unit rampForProgram:0];
  assert([savedRamp[@"bars"] intValue]==1&&[savedRamp[@"enabled"] boolValue]&&![savedRamp[@"temporary"] boolValue]);
  tick();
  const NSUInteger beforeRampMiddle=messages.count;
  beat+=2;tick();
  const int savedMid=beat4::tempoPitchBend14(141.75);
  assert(messages.count==beforeRampMiddle+1);
  assert(([messages.lastObject[@"bytes"] isEqual:@[@238,@(savedMid&127),@(savedMid>>7)]]));
  [unit previewRamp:2 enabled:YES program:0 apply:NO];
  [unit saveRampForProgram:0];
  assert([[unit rampForProgram:0][@"bars"] intValue]==2);
  beat+=2;tick();
  const int savedEnd=beat4::tempoPitchBend14(148);
  assert(([messages.lastObject[@"bytes"] isEqual:@[@238,@(savedEnd&127),@(savedEnd>>7)]]));
  NSData *trace=[NSJSONSerialization dataWithJSONObject:@{@"host":@"SIMULATED",@"midiOutput":messages,@"journal":unit.diagnosticLog} options:NSJSONWritingPrettyPrinted error:&error];
  assert(trace && !error && [trace writeToFile:[directory stringByAppendingPathComponent:@"mock-host-midi-trace.json"] atomically:YES]);
  // A host may query the block before negotiation and install callbacks after allocation.
  Beat4AudioUnit *late=[[Beat4AudioUnit alloc]initWithComponentDescription:desc options:0 error:&error];
  AUInternalRenderBlock lateRender=late.internalRenderBlock;
  assert([late allocateRenderResourcesAndReturnError:&error]);
  [late deallocateRenderResources];
  AVAudioFormat *format=[[AVAudioFormat alloc]initStandardFormatWithSampleRate:44100 channels:2];
  assert([late.outputBusses[0] setFormat:format error:&error]);
  assert([late allocateRenderResourcesAndReturnError:&error]);
  late.musicalContextBlock=unit.musicalContextBlock;
  late.transportStateBlock=unit.transportStateBlock;
  late.MIDIOutputEventBlock=unit.MIDIOutputEventBlock;
  // No snapshot/UI call: host setter publication must work with the editor closed.
  float lateSamples[256]={};AudioBufferList lateBuffers{};lateBuffers.mNumberBuffers=1;
  lateBuffers.mBuffers[0]={2,sizeof(lateSamples),lateSamples};
  AudioTimeStamp lateStamp{};lateStamp.mFlags=kAudioTimeStampSampleTimeValid;
  AudioUnitRenderActionFlags lateFlags=kAudioUnitRenderAction_OutputIsSilence;
  assert(lateRender(&lateFlags,&lateStamp,128,0,&lateBuffers,nullptr,nil)==noErr);
  NSDictionary *lateSnapshot=late.transportSnapshot;
  assert([lateSnapshot[@"synced"] boolValue]);
  assert([lateSnapshot[@"renderSampleRate"] doubleValue]==44100);
  assert(!(lateFlags&kAudioUnitRenderAction_OutputIsSilence));
  [late deallocateRenderResources];
  // A malformed successful callback must not be advertised as synchronized.
  late.musicalContextBlock=^BOOL(double *tempo,double *num,NSInteger *den,double *position,NSInteger *offset,double *downbeat){
   (void)offset;if(tempo)*tempo=128;if(num)*num=NAN;if(den)*den=4;
   if(position)*position=INFINITY;if(downbeat)*downbeat=0;return YES;
  };
  assert([late allocateRenderResourcesAndReturnError:&error]);
  lateStamp.mSampleTime=NAN;
  assert(lateRender(&lateFlags,&lateStamp,128,0,&lateBuffers,nullptr,nil)==noErr);
  assert(![late.transportSnapshot[@"synced"] boolValue]);
  assert([late.transportSnapshot[@"invalidTimestamps"] unsignedLongLongValue]>0);
  [late deallocateRenderResources];
  [@"PASS: 12 native UIKit renders, ACTIVE/SELECTED, grid colors, AUv3 MIDI anti-echo and Pitch Bend tempo on simulated host\n" writeToFile:[directory stringByAppendingPathComponent:@"DONE.txt"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
  assert(!error);[unit deallocateRenderResources];
 } @catch(NSException *exception){
  NSLog(@"R10 snapshot failure: %@",exception);abort();
 }
 return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(SnapshotApp.class));}}
