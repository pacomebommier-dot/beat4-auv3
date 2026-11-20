#pragma once
#import <Foundation/Foundation.h>
#include "Beat4Songs.hpp"
#include "Beat4Relay.hpp"
namespace beat4 {
inline double storedNumber(id value,double fallback=0){
 return [value isKindOfClass:NSNumber.class]?[(NSNumber*)value doubleValue]:fallback;
}
inline bool namedSong(NSDictionary *song){
 NSString *name=[song[@"title"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 return name.length&&[name caseInsensitiveCompare:@"UNKNOWN"]!=NSOrderedSame;
}
inline bool maskSong(NSDictionary *song){
 NSString *name=song[@"title"];
 return name.length&&[name caseInsensitiveCompare:@"Mask"]==NSOrderedSame;
}
inline int songRampBars(NSDictionary *song){
 return song[@"rampBars"]?(int)storedNumber(song[@"rampBars"],-1):(namedSong(song)&&!maskSong(song)?4:-1);
}
inline bool songRampEnabled(NSDictionary *song){
 return namedSong(song)&&songRampBars(song)>=0&&(song[@"rampEnabled"]?[song[@"rampEnabled"] boolValue]:!maskSong(song));
}
inline int songTempoRamp(NSDictionary *song){return songRampEnabled(song)?songRampBars(song):-1;}
inline RelaySettings songRelaySettings(NSDictionary *song){
 return {namedSong(song)&&[song[@"relayEnabled"] boolValue],
  std::clamp((int)storedNumber(song[@"relayBars"],1),1,15),
  std::clamp((int)storedNumber(song[@"relayFadeBars"],1),1,24)};
}
inline NSMutableDictionary *loadSongStore(NSUserDefaults *defaults){
 NSDictionary *saved=[defaults dictionaryForKey:@"beat4.songs.v2"];
 if(!saved)saved=[defaults dictionaryForKey:@"beat4.songs.v1"];
 NSMutableDictionary *result=[NSMutableDictionary new];
 [saved enumerateKeysAndObjectsUsingBlock:^(id key,id value,BOOL *stop){
  (void)stop;
  if(![key isKindOfClass:NSString.class] || ![value isKindOfClass:NSDictionary.class])return;
  int pc=[key intValue];
  if(pc<0 || pc>=64 || ![key isEqualToString:[NSString stringWithFormat:@"%d",pc]])return;
  NSDictionary *entry=value;
  int sub=(int)storedNumber(entry[@"sub"],-1);
  NSMutableDictionary *song=[@{@"title":[entry[@"title"] isKindOfClass:NSString.class]?entry[@"title"]:@"UNKNOWN",
    @"bpm":@(storedBPM(storedNumber(entry[@"bpm"]))),@"sub":@(validSub(sub)?sub:-1),
    @"steps":@(storedNumber(entry[@"steps"],16)==32?32:16),
    @"queue":@(storedQueue((int)storedNumber(entry[@"queue"]))),
    @"pcMode":@(storedMode((int)storedNumber(entry[@"pcMode"],-1)))} mutableCopy];
  for(NSString *field in @[@"rampBars",@"rampEnabled"])if([entry[field] isKindOfClass:NSNumber.class])song[field]=entry[field];
  if([entry[@"padColor"] isKindOfClass:NSString.class])song[@"padColor"]=entry[@"padColor"];
  auto relay=songRelaySettings(entry);song[@"relayEnabled"]=@(relay.enabled);song[@"relayBars"]=@(relay.bars);song[@"relayFadeBars"]=@(relay.fade);
  result[key]=song;
 }];return result;
}
inline void writeSongStore(NSUserDefaults *defaults,NSDictionary *songs){
 [defaults setObject:songs forKey:@"beat4.songs.v2"];
}
}
