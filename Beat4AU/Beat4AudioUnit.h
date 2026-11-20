#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN
@interface Beat4AudioUnit : AUAudioUnit
// Main-thread API. MIDI/render callback reads only realtime-safe atomics.
- (nullable NSDictionary *)previewConfigurationData:(NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (BOOL)importConfigurationData:(NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)exportConfigurationData:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, NSNumber *> *)transportSnapshot;
- (uint64_t)displayRevision;
- (NSInteger)currentProgram;
- (NSDictionary<NSString *, id> *)currentSong;
- (void)saveSongTitle:(NSString *)title;
- (void)saveSongTitle:(NSString *)title program:(NSInteger)pg;
- (void)saveSongBPM:(double)bpm;
- (void)saveSongBPM:(double)bpm program:(NSInteger)pg;
- (void)saveSongSubNote:(NSInteger)note;
- (void)setKickLevel:(float)level;
- (void)setKickEnabled:(BOOL)enabled;
- (NSArray *)diagnosticLog;
- (void)requestTransportToggle;
- (void)requestPlayGestureLong:(BOOL)isLong;
- (NSDictionary *)setSnapshot;
- (void)setEnabled:(BOOL)enabled;
- (void)assignSetPosition:(NSInteger)index program:(NSInteger)pc;
- (void)selectSetPosition:(NSInteger)index;
- (void)resetSetCache;
- (void)selectProgram:(NSInteger)pc;
- (void)setCycleSteps:(NSInteger)steps;
- (void)saveCurrentCycle;
- (void)saveCycleSteps:(NSInteger)steps program:(NSInteger)pc;
- (NSDictionary *)songForProgram:(NSInteger)pc;
- (NSDictionary *)rampForProgram:(NSInteger)pc;
- (void)previewRamp:(NSInteger)bars enabled:(BOOL)enabled program:(NSInteger)pc apply:(BOOL)apply;
- (void)saveRampForProgram:(NSInteger)pc;
- (void)savePadColor:(NSString *)color program:(NSInteger)pc;
- (NSDictionary *)relayForProgram:(NSInteger)pc;
- (void)saveRelayEnabled:(BOOL)enabled bars:(NSInteger)bars fade:(NSInteger)fade program:(NSInteger)pc;
- (void)saveQueue:(NSInteger)beats program:(NSInteger)pc;
@end
NS_ASSUME_NONNULL_END
