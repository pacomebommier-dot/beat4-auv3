#import <AudioToolbox/AudioToolbox.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN
@interface Beat4AudioUnit : AUAudioUnit
// Main-thread API. MIDI/render callback reads only realtime-safe atomics.
- (NSDictionary<NSString *, NSNumber *> *)transportSnapshot;
- (uint64_t)displayRevision;
- (BOOL)safetyMIDIEnabled;
- (void)setSafetyMIDIEnabled:(BOOL)enabled;
- (NSInteger)currentProgram;
- (NSDictionary<NSString *, id> *)currentSong;
- (void)saveSongTitle:(NSString *)title;
- (void)saveSongBPM:(double)bpm;
- (void)saveSongSubNote:(NSInteger)note;
- (void)setKickLevel:(float)level;
- (void)setKickEnabled:(BOOL)enabled;
- (void)requestMMC:(uint8_t)command;
@end
NS_ASSUME_NONNULL_END
