#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN
@interface Beat4AudioUnit : AUAudioUnit
// Main-thread API. MIDI/render callback reads only realtime-safe atomics.
- (NSDictionary<NSString *, NSNumber *> *)transportSnapshot;
- (NSInteger)currentProgram;
- (NSDictionary<NSString *, id> *)currentSong;
- (void)saveSongTitle:(NSString *)title;
- (void)saveSongBPM:(double)bpm;
- (void)saveSongSubNote:(NSInteger)note;
- (void)setKickLevel:(float)level;
- (void)setKickEnabled:(BOOL)enabled;
- (void)requestTransportToggle;
- (void)selectProgram:(NSInteger)pc;
- (void)setGlobalMode:(NSInteger)mode;
- (void)saveCurrentMode;
- (NSDictionary *)songForProgram:(NSInteger)pc;
- (void)saveQueue:(NSInteger)beats program:(NSInteger)pc;
@end
NS_ASSUME_NONNULL_END
