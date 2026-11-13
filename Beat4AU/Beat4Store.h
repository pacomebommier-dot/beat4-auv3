#pragma once
#import <Foundation/Foundation.h>
#include "Beat4Songs.hpp"
namespace beat4 {
inline double storedNumber(id value,double fallback=0){
 return [value isKindOfClass:NSNumber.class]?[(NSNumber*)value doubleValue]:fallback;
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
  result[key]=@{@"title":[entry[@"title"] isKindOfClass:NSString.class]?entry[@"title"]:@"UNKNOWN",
    @"bpm":@(storedBPM(storedNumber(entry[@"bpm"]))),@"sub":@(validSub(sub)?sub:-1),
    @"queue":@(storedQueue((int)storedNumber(entry[@"queue"]))),
    @"pcMode":@(storedMode((int)storedNumber(entry[@"pcMode"],-1)))};
 }];return result;
}
inline void writeSongStore(NSUserDefaults *defaults,NSDictionary *songs){
 [defaults setObject:songs forKey:@"beat4.songs.v2"];
}
}
