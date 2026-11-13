#import <UIKit/UIKit.h>
#import "../Beat4AU/Beat4ViewController.h"
#import "../Beat4AU/Beat4AudioUnit.h"
#include <cassert>
#include <cmath>
#import <QuartzCore/QuartzCore.h>

@interface Beat4ViewController (SnapshotTest)
- (void)updateDisplay:(CADisplayLink *)link;
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
  __block BOOL moving=NO;__block double beat=0;
  unit.musicalContextBlock=^BOOL(double *tempo,double *num,NSInteger *den,double *position,NSInteger *offset,double *downbeat){
   if(tempo)*tempo=128;if(num)*num=4;if(den)*den=4;if(position)*position=beat;
   if(offset)*offset=0;if(downbeat)*downbeat=std::floor(beat/4)*4;return YES;
  };
  unit.transportStateBlock=^BOOL(AUHostTransportStateFlags *flags,double *sample,double *start,double *end){
   if(flags)*flags=moving?AUHostTransportStateMoving:(AUHostTransportStateFlags)0;
   if(sample)*sample=beat*48000*60/128;if(start)*start=0;if(end)*end=0;return YES;
  };
  NSMutableArray *messages=[NSMutableArray new];
  unit.MIDIOutputEventBlock=^OSStatus(AUEventSampleTime time,uint8_t cable,NSInteger length,const uint8_t *bytes){
   NSMutableArray *data=[NSMutableArray new];for(NSInteger i=0;i<length;++i)[data addObject:@(bytes[i])];
   [messages addObject:@{@"sample":@(time),@"cable":@(cable),@"bytes":data}];return noErr;
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
  [unit saveSongTitle:@"R10 NATIVE TEST"];[unit saveSongBPM:135];[unit saveSongSubNote:5];
  [unit setGlobalMode:1];[unit saveCurrentMode];
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
    NSArray<UIButton*> *pads=[vc valueForKey:@"pads"];assert(pads.count==32);
    UILabel *header=[vc valueForKey:@"pgLabel"];
    assert([header.text containsString:@"ACTIVE PC 007"] && [header.text containsString:@"SELECTED 40"]);
    if(page>0){
     for(UIButton *pad in pads){
      int pc=(page-1)*32+(int)pad.tag;
      assert(!pad.hidden);
      assert([pad.accessibilityLabel containsString:pc==7?@"ACTIF":pc==39?@"SÉLECTIONNÉ":@"ÉTEINT"]);
      CGFloat r=0,g=0,b=0,a=0;assert([pad.backgroundColor getRed:&r green:&g blue:&b alpha:&a]);
      assert(pc==7?r>.9:pc==39?r>.5 && r<.6:r<.15);
     }
    }
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=1;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:size format:format];
    UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[vc.view.layer renderInContext:context.CGContext];}];
    NSString *file=[NSString stringWithFormat:@"%@/%.0fx%.0f_page%d.png",directory,size.width,size.height,page];
    assert([UIImagePNGRepresentation(image) writeToFile:file atomically:YES]);
   }
  }
  AURenderEvent event{};event.head.eventType=AURenderEventMIDI;event.head.eventSampleTime=AUEventSampleTimeImmediate;
  event.MIDI.length=2;event.MIDI.data[0]=0xCF;event.MIDI.data[1]=103;input=&event;tick();
  assert(unit.currentProgram==7 && [unit.transportSnapshot[@"uncertain"] boolValue] && messages.count==1);
  event.MIDI.data[1]=39;tick();assert(unit.currentProgram==39 && messages.count==1);input=nullptr;
  [unit requestTransportToggle];tick();tick();
  NSArray *stopPress=@[@191,@111,@127],*stopRelease=@[@191,@111,@0];
  assert(messages.count==3 && [messages[1][@"bytes"] isEqual:stopPress] && [messages[2][@"bytes"] isEqual:stopRelease]);
  moving=NO;[unit requestTransportToggle];tick();tick();
  NSArray *playPress=@[@191,@110,@127],*playRelease=@[@191,@110,@0];
  assert(messages.count==5 && [messages[3][@"bytes"] isEqual:playPress] && [messages[4][@"bytes"] isEqual:playRelease]);
  NSData *trace=[NSJSONSerialization dataWithJSONObject:@{@"host":@"SIMULATED",@"midiOutput":messages,@"journal":unit.diagnosticLog} options:NSJSONWritingPrettyPrinted error:&error];
  assert(trace && !error && [trace writeToFile:[directory stringByAppendingPathComponent:@"mock-host-midi-trace.json"] atomically:YES]);
  [@"PASS: 12 native UIKit renders, ACTIVE/SELECTED, grid colors and AUv3 MIDI anti-echo on simulated host\n" writeToFile:[directory stringByAppendingPathComponent:@"DONE.txt"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
  assert(!error);[unit deallocateRenderResources];
 } @catch(NSException *exception){
  NSLog(@"R10 snapshot failure: %@",exception);abort();
 }
 return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(SnapshotApp.class));}}
