#import <Foundation/Foundation.h>
#import "../Beat4AU/Beat4Config.h"
#include <cassert>
static NSData *json(id x){return [NSJSONSerialization dataWithJSONObject:x options:0 error:nil];}
static NSDictionary *parse(id x){NSError *e=nil;auto p=beat4::parseConfigurationData(json(x),&e);assert(p&&!e);return p;}
int main(){@autoreleasepool{
 auto patch=parse(@{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"name":@"TEST",@"bpm":@240,@"sub":@"Ré"},@{@"song":@64,@"sub":@"Do♯"}]});
 assert([patch[@"songs"][@"0"][@"sub"] intValue]==2);
 assert([patch[@"songs"][@"63"][@"sub"] intValue]==1);
 auto merged=beat4::mergeSongPatches(@{@"0":@{@"steps":@32,@"queue":@8},@"7":@{@"title":@"KEEP",@"bpm":@123}},patch[@"songs"]);
 assert([merged[@"0"][@"bpm"] intValue]==240&&[merged[@"0"][@"steps"] intValue]==32);
 assert([merged[@"0"][@"queue"] intValue]==8&&[merged[@"7"][@"title"] isEqual:@"KEEP"]);
 NSError *e=nil;auto bytes=beat4::configurationData(merged,nil,&e);assert(bytes&&!e);
 auto back=beat4::parseConfigurationData(bytes,&e);assert(back&&!e);
 assert([back[@"songs"][@"0"][@"title"] isEqual:@"TEST"]);
 auto set=parse(@{@"format":@"BEAT4_CONFIG",@"version":@1,@"set":@{@"slots":@[[NSNull null],@64,@1,[NSNull null],[NSNull null],[NSNull null],[NSNull null],[NSNull null]],@"on":@YES}});
 assert([set[@"set"][@"cursor"] intValue]==1&&[set[@"set"][@"slots"][1] intValue]==63);
 // Clearing the current pad preserves its traversal position; export must work.
 NSDictionary *cleared=@{@"slots":@[@(-1),@(-1),@3,@(-1),@(-1),@(-1),@(-1),@(-1)],@"on":@YES,@"cursor":@1,@"restart":@NO};
 e=nil;NSData *clearedData=beat4::configurationData(merged,cleared,&e);assert(clearedData&&!e);
 auto clearedRoundTrip=beat4::parseConfigurationData(clearedData,&e);assert([clearedRoundTrip[@"set"][@"cursor"] intValue]==1);
 NSArray *bad=@[
  @{@"songs":@[]},
  @{@"format":@"BEAT4_CONFIG",@"version":@2,@"songs":@[]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@0,@"bpm":@120}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"bpm":@120},@{@"song":@1,@"sub":@"C"}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"bpm":@241}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"bpm":@YES}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1.5,@"sub":@"C"}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"sub":@"C MINEUR"}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"steps":@17}]},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"set":@{@"slots":@[@1],@"on":@YES}},
  @{@"format":@"BEAT4_CONFIG",@"version":@1,@"songs":@[@{@"song":@1,@"bpmm":@120}]}
 ];
 for(id b in bad){e=nil;assert(!beat4::parseConfigurationData(json(b),&e)&&e);}
 e=nil;assert(!beat4::parseConfigurationData([@"{" dataUsingEncoding:NSUTF8StringEncoding],&e)&&e);
 puts("Configuration JSON: partial merge, notes, range/duplicate/schema/type validation, SET and roundtrip PASS");
}}
