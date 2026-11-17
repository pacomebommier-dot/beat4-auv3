#pragma once
#import <Foundation/Foundation.h>
#include <cmath>
#include "Beat4Songs.hpp"
namespace beat4 {
inline id configError(NSError **error,NSString *message){
 if(error)*error=[NSError errorWithDomain:@"BEAT4.Configuration" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return nil;
}
inline bool configNumber(id x,double lo,double hi,bool integer=true){
 if(![x isKindOfClass:NSNumber.class]||CFGetTypeID((__bridge CFTypeRef)x)==CFBooleanGetTypeID())return false;
 double n=[x doubleValue];return std::isfinite(n)&&n>=lo&&n<=hi&&(!integer||n==std::floor(n));
}
inline bool configBool(id x){return [x isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)x)==CFBooleanGetTypeID();}
inline bool configKeys(NSDictionary *d,NSArray *allowed){for(id k in d)if(![allowed containsObject:k])return false;return true;}
inline int configNote(id x){
 if(![x isKindOfClass:NSString.class])return -2;
 NSString *s=[[[x stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString] stringByReplacingOccurrencesOfString:@"♯" withString:@"#"];
 s=[[s stringByReplacingOccurrencesOfString:@"♭" withString:@"B"] stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"fr_FR"]];
 if([s isEqual:@"--"])return -1;
 NSDictionary *names=@{@"C":@0,@"DO":@0,@"C#":@1,@"DO#":@1,@"DB":@1,@"REB":@1,@"D":@2,@"RE":@2,@"D#":@3,@"RE#":@3,@"EB":@3,@"MIB":@3,@"E":@4,@"MI":@4,@"F":@5,@"FA":@5,@"F#":@6,@"FA#":@6,@"GB":@6,@"SOLB":@6,@"G":@7,@"SOL":@7,@"G#":@8,@"SOL#":@8,@"AB":@8,@"LAB":@8,@"A":@9,@"LA":@9,@"A#":@10,@"LA#":@10,@"BB":@10,@"SIB":@10,@"B":@11,@"SI":@11};
 return names[s]?[names[s] intValue]:-2;
}
inline NSDictionary *parseConfigurationData(NSData *data,NSError **error){
 if(!data||data.length>1024*1024)return configError(error,@"Fichier absent ou trop volumineux (maximum 1 Mo).");
 id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];
 if(![root isKindOfClass:NSDictionary.class])return configError(error,@"Le fichier doit contenir une configuration JSON BEAT4.");
 NSDictionary *d=root;
 if(![d[@"format"] isEqual:@"BEAT4_CONFIG"]||!configNumber(d[@"version"],1,1)||!configKeys(d,@[@"format",@"version",@"songs",@"set"]))return configError(error,@"Format ou version de configuration non reconnu.");
 if(!d[@"songs"]&&!d[@"set"])return configError(error,@"Aucun SONG ni SET dans ce fichier.");
 NSMutableDictionary *result=[NSMutableDictionary new],*patches=[NSMutableDictionary new];
 if(d[@"songs"]){
  if(![d[@"songs"] isKindOfClass:NSArray.class]||[d[@"songs"] count]>64)return configError(error,@"La liste SONGS doit contenir au plus 64 entrées.");
  for(id item in d[@"songs"]){
   if(![item isKindOfClass:NSDictionary.class])return configError(error,@"Entrée SONG invalide.");
   NSDictionary *row=item;
   if(!configKeys(row,@[@"song",@"name",@"bpm",@"sub",@"steps",@"queue",@"pcMode"])||!configNumber(row[@"song"],1,64)||row.count<2)return configError(error,@"SONG attendu : numéro 1–64 et au moins un champ reconnu.");
   NSString *key=[NSString stringWithFormat:@"%d",[row[@"song"] intValue]-1];
   if(patches[key])return configError(error,@"Un numéro SONG apparaît plusieurs fois.");
   NSMutableDictionary *p=[NSMutableDictionary new];
   if(row[@"name"]){
    if(![row[@"name"] isKindOfClass:NSString.class])return configError(error,@"Le nom doit être du texte.");
    NSString *name=[row[@"name"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(name.length==0||name.length>160)return configError(error,@"Le nom doit contenir entre 1 et 160 caractères.");
    p[@"title"]=name;
   }
   if(row[@"bpm"]){if(!configNumber(row[@"bpm"],0,240)||([row[@"bpm"] intValue]>0&&[row[@"bpm"] intValue]<20))return configError(error,@"BPM attendu : entier 20–240, ou 0 pour non renseigné.");p[@"bpm"]=row[@"bpm"];}
   if(row[@"sub"]){int note=configNote(row[@"sub"]);if(note< -1)return configError(error,@"SUB attendu : une note seule (C, Do, Ré, Do#…), ou --.");p[@"sub"]=@(note);}
   if(row[@"steps"]){if(!configNumber(row[@"steps"],16,32)||([row[@"steps"] intValue]!=16&&[row[@"steps"] intValue]!=32))return configError(error,@"Cycle attendu : 16 ou 32 steps.");p[@"steps"]=row[@"steps"];}
   if(row[@"queue"]){if(!configNumber(row[@"queue"],0,65536))return configError(error,@"QUEUE invalide.");p[@"queue"]=row[@"queue"];}
   if(row[@"pcMode"]){if(!configNumber(row[@"pcMode"],-1,2))return configError(error,@"Mode historique invalide.");p[@"pcMode"]=row[@"pcMode"];}
   patches[key]=p;
  }
  result[@"songs"]=patches;
 }
 if(d[@"set"]){
  if(![d[@"set"] isKindOfClass:NSDictionary.class])return configError(error,@"SET invalide.");
  NSDictionary *set=d[@"set"];NSArray *slots=set[@"slots"];
  if(!configKeys(set,@[@"slots",@"on",@"cursor",@"restart"])||![slots isKindOfClass:NSArray.class]||slots.count!=8)return configError(error,@"Le SET doit contenir exactement huit positions.");
  NSMutableArray *normalized=[NSMutableArray new];int first=-1;
  for(id x in slots){if(x!=NSNull.null&&!configNumber(x,1,64))return configError(error,@"Une position SET doit contenir un SONG 1–64 ou null.");int pc=x==NSNull.null?-1:[x intValue]-1;if(pc>=0&&first<0)first=(int)normalized.count;[normalized addObject:@(pc)];}
  if((set[@"on"]&&!configBool(set[@"on"]))||(set[@"restart"]&&!configBool(set[@"restart"])))return configError(error,@"ON et restart doivent être true ou false.");
  int cursor=first;
  if(set[@"cursor"]){if(set[@"cursor"]==NSNull.null)cursor=-1;else if(configNumber(set[@"cursor"],1,8))cursor=[set[@"cursor"] intValue]-1;else return configError(error,@"Curseur SET attendu : position 1–8 ou null.");}
  result[@"set"]=@{@"slots":normalized,@"on":@([set[@"on"] boolValue]&&first>=0),@"cursor":@(cursor),@"restart":@(first>=0&&(set[@"restart"]?[set[@"restart"] boolValue]:YES))};
 }
 return result;
}
inline NSMutableDictionary *mergeSongPatches(NSDictionary *existing,NSDictionary *patches){
 NSMutableDictionary *songs=[existing mutableCopy]?:[NSMutableDictionary new];
 for(NSString *key in patches){
  NSMutableDictionary *entry=[@{@"title":@"UNKNOWN",@"bpm":@0,@"sub":@(-1),@"steps":@16,@"queue":@0,@"pcMode":@(-1)} mutableCopy];
  [entry addEntriesFromDictionary:songs[key]?:@{}];[entry addEntriesFromDictionary:patches[key]];songs[key]=entry;
 }return songs;
}
inline NSData *configurationData(NSDictionary *songs,NSDictionary *set,NSError **error){
 NSMutableDictionary *root=[@{@"format":@"BEAT4_CONFIG",@"version":@1} mutableCopy];
 if(songs){NSMutableArray *rows=[NSMutableArray new];
  for(int pc=0;pc<64;++pc){NSDictionary *s=songs[[NSString stringWithFormat:@"%d",pc]];if(!s)continue;
   NSMutableDictionary *r=[@{@"song":@(pc+1),@"name":s[@"title"]?:@"UNKNOWN",@"bpm":s[@"bpm"]?:@0,@"sub":[NSString stringWithUTF8String:noteName(s[@"sub"]?[s[@"sub"] intValue]:-1)]} mutableCopy];
   for(NSString *k in @[@"steps",@"queue",@"pcMode"])if(s[k])r[k]=s[k];[rows addObject:r];
  }root[@"songs"]=rows;
 }
 if(set){NSMutableArray *slots=[NSMutableArray new];for(NSNumber *n in set[@"slots"])[slots addObject:n.intValue<0?(id)NSNull.null:@(n.intValue+1)];
  int cursor=[set[@"cursor"] intValue];root[@"set"]=@{@"slots":slots,@"on":@([set[@"on"] boolValue]),@"cursor":cursor<0?(id)NSNull.null:@(cursor+1),@"restart":@([set[@"restart"] boolValue])};
 }
 NSData *data=[NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:error];
 if(data&&!parseConfigurationData(data,error))return nil;return data;
}
}
