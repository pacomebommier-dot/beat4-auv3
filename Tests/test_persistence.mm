#import <Foundation/Foundation.h>
#import "../Beat4AU/Beat4Store.h"
#include <cassert>
int main(){@autoreleasepool {
 NSString *name=[@"beat4.r10.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
 NSUserDefaults *d=[[NSUserDefaults alloc]initWithSuiteName:name];
 [d setObject:@{@"7":@{@"title":@"LEGACY",@"bpm":@128.6,@"sub":@5},@"71":@{@"title":@"RAW ARCHIVE",@"bpm":@160},@"bad":@{@"bpm":@180}} forKey:@"beat4.songs.v1"];
 auto songs=beat4::loadSongStore(d);assert(songs.count==1 && [songs[@"7"][@"bpm"] intValue]==129);
 assert([d dictionaryForKey:@"beat4.songs.v1"][@"71"]!=nil);
 NSMutableDictionary *song=[songs[@"7"] mutableCopy];song[@"queue"]=@8;song[@"pcMode"]=@2;songs[@"7"]=song;
 beat4::writeSongStore(d,songs);auto restored=beat4::loadSongStore(d);
 assert([restored[@"7"][@"queue"] intValue]==8 && [restored[@"7"][@"pcMode"] intValue]==2);
 song=[restored[@"7"] mutableCopy];song[@"pcMode"]=@0;restored[@"7"]=song;beat4::writeSongStore(d,restored);
 restored=beat4::loadSongStore(d);assert([restored[@"7"][@"bpm"] intValue]==129 && [restored[@"7"][@"queue"] intValue]==8);
 [d setObject:@{@"0":@{@"bpm":@[],@"queue":@(-1),@"pcMode":@8,@"sub":@99}} forKey:@"beat4.songs.v2"];
 restored=beat4::loadSongStore(d);assert([restored[@"0"][@"bpm"] intValue]==0 && [restored[@"0"][@"pcMode"] intValue]==-1);
 [d removePersistentDomainForName:name];puts("R10 native persistence/migration PASS");
}}
