> ARCHIVE HISTORIQUE V05 — directives remplacées par le contrat consolidé R10. Ne pas utiliser comme recette actuelle.

# BEAT//4 — AUv3 for AUM

**Source milestone V0.5 (2026-11-10): portable tests + ASan/UBSan PASS; native iOS build and AUM routing still unverified.**
This is a **fully separate project** from XONE. Its GitHub repository, build, signing, bundle identifiers and data store must stay independent. Do **not** add these files to `xone-auv3-test`.

## Design contract

- Dark, minimal, 1980s lo-fi industrial aesthetic; no neon gamer UI.
- Four **large vertical phosphorescent bars**, spaced well apart, visible when off; no numbers inside.
- Beat light ramps up gradually, then releases faster. Phase follows AUM host quarter-beat position. No autonomous metronome timer.
- The rest is intentionally small and integrated in the same page: AUM BPM/host status, current PG, SONG, SONG BPM, KICK ON/OFF, SUB note, KICK LEVEL and transport buttons.
- Responsive UIKit layout intended for AUv3 windows on iPhone and iPad.
- `docs/approved-concept.png` is the **user-approved visual reference**; the UIKit implementation is code and is NOT claimed to have been verified pixel-by-pixel on device.

## Song memory contract (important)

One independent record per **raw incoming Program Change 0–127 on MIDI channel 16**:

| Attribute | Per SONG (PG)? | Behavior |
|---|---|---|
| Name | Yes | UNKNOWN until entered; touch to edit |
| Target BPM | Yes | No outgoing tempo if unknown; touch to edit |
| Kick sub pitch class | **YES** | Unknown until entered; touch note for selection |
| Kick LEVEL | No, global | Drag slider, or control with AUM's native MIDI Learn |
| KICK ON/OFF | No, global | Tap KICK; exposed as another AUv3 parameter |

Raw PC `6` and `70` are treated as **different** PG values; no queued-song logic or assumptions about what is physically playing on Circuit Tracks. The last received PG is displayed.

Memory uses extension-local `NSUserDefaults` under `beat4.songs.v1`. The audio render callback only reads preloaded atomics; it never touches disk or allocates. Memory survives extension restart if iOS retains its app extension preferences. App deletion may erase that storage. Same PG from another Circuit pack will reuse the stored name/BPM/note; pack selection is not detected.

## AUv3 signal path

AUv3 `aumu` **instrument** (not a silent `augn` generator): AUM can route the Circuit Tracks MIDI Program Change directly to a music-device plugin, and the plugin can generate a stereo kick. The subtype is still `bt04`; bundle identifiers remain under `com.example.beat4` until configured for your own signing.

- Audio: fixed analog-style kick voice, an independent fixed-pitch transient and a sub tail tuned to the SONG's pitch class in octave 1. Transients are intentionally unchanged by NOTE.
- Kick is **OFF by default**, to avoid unexpected audio on project opening.
- BEAT//4 exposes AUv3 `Kick Level` and `Kick ON/OFF` parameters. In AUM's plugin window tap MIDI Controls → find Kick Level → LEARN; move your hardware fader. No in-app MIDI Learn is implemented.
- The beat gate holds its previous trigger index across audio render buffers (fix V0.5: no spurious kick on the second sample of each buffer). The engine uses AUM musical beat position, not the Circuit's own clock. AUM is intended to send its MIDI Clock to Circuit Tracks.
- Transport UI buttons request MMC PLAY (0x02), PAUSE (0x09), STOP (0x01) via MIDI output; they do not pretend to directly set host state. AUM must have **Receive MMC** enabled and BEAT4 MIDI output routed to AUM MIDI Control.

### Automatic SONG tempo → AUM

BEAT//4 sends MIDI Pitch Bend **channel 15** (0xEE, 14-bit), once when a known PG is recalled or its BPM is entered, with numeric mapping **20–240 BPM** → PBEND 0–16383. AUM must be configured ONCE to match:

1. In the MIDI Matrix connect **Circuit Tracks MIDI OUT → BEAT//4 MIDI IN**. Filter to channel 16 / PC if appropriate. Do not send Clock from Circuit into BEAT//4.
2. Connect **BEAT//4 MIDI OUT → AUM's `MIDI Control` destination**. Do not route this output to Circuit Tracks.
3. Under **AUM MIDI Control → Transport → Tempo**, choose `PBEND`, MIDI channel **15**, range **20–240 BPM**, and use LEARN or manual mapping. Verify AUM displays the exact desired BPM before playing.
4. Enable AUM `Receive MMC` in its transport settings if using our remote transport buttons.
5. Route **AUM MIDI Clock Send → Circuit Tracks MIDI IN** and set Circuit Tracks to receive external clock; avoid a two-master MIDI clock loop.
6. Save the AUM session with these connections and mapping.

**Host limitations:** Direct AUv3 MIDI output routing, its callback's availability when loading a new instrument, and exact AUM tempo mapping require validation on the real iOS/AUM setup. The `MIDIOutputEventBlock` may not be present in every host. If it is unavailable, SONG/PG/UI/kick still work locally but tempo/MMC do not reach AUM. AUM tempo might differ in decimal rounding; compare the host readback against the stored target.

Responsive layout geometry is verified for 8 iPhone and iPad viewport sizes (320×200 through 1194×834). The 4 beat bars and kick are currently defined for **4/4**. If AUM is set to another signature, the kick does not trigger, to avoid misleading rhythm. The host position/transport flags cannot always distinguish PAUSE versus STOP without rewind; the UI prioritizes actual moving/stationary state.

## Build

On a Mac, open `Beat4.xcodeproj`, choose `Beat4App`, configure **unique signing IDs** for *both* app and extension, and Build/Run on iPhone or iPad. In AUM choose the plugin as an **Audio Unit Instrument**, not an Audio Unit Generator. Set up the MIDI routing above.

GitHub Actions `.github/workflows/ios.yml` is included for a **new BEAT//4 repository only**. It runs portable tests, attempts an iOS device build on a macOS runner, then archives an **unsigned** IPA artifact. An unsigned IPA is **not directly installable** on an iPhone; device signing/sideloading is a separate step. This environment has no macOS/Xcode/iOS SDK, so we cannot claim the workflow has passed or that an installable IPA was produced.

## Test commands

```sh
bash Tests/run.sh
CXX=clang++ BEAT4_SANITIZE=1 bash Tests/run.sh
```

### On-device acceptance tests (not yet performed)

See `docs/RECETTE_AUM_V05.md` for the step-by-step check. A `Tools/render_kick.cpp` portable tool produces `audio-demo/BEAT4_kick_F1_128BPM.wav`, four beats at 128 BPM; this is a synthesized reference sample, NOT an AUM capture.

- [ ] AUM identifies BEAT//4 as an instrument; MIDI IN and MIDI OUT appear in AUM.
- [ ] MIDI PC `6` (channel 16) shows `PG 006`; unknown fields are UNKNOWN / --.- BPM / --.
- [ ] Save title DARK ROOM, BPM 128, SUB F under PG 6. Save HYPNOTIC / 124 / G under PG 7; switch back and forth; all 3 independent values return.
- [ ] Kill AUM/reload extension; saved song data survives.
- [ ] PG 70 is NOT silently coalesced into PG 6.
- [ ] AUM with matching PBEND mapping changes to 128 / 124 on corresponding PG, with no unrelated transport start.
- [ ] Unknown PG does not change the current AUM BPM.
- [ ] AUM MIDI Clock drives Circuit Tracks in slave mode without a feedback loop.
- [ ] Four bars follow actual AUM play/pause/seek/tempo changes and remain legible from a distance.
- [ ] KICK button switches audio on/off, and the sub F/G changes only the sustained fundamental.
- [ ] MIDI Learn in AUM controls exactly the same Kick Level as the on-screen LEVEL slider.
- [ ] AUM responds to MMC PLAY/PAUSE/STOP from BEAT//4, when configured.
- [ ] CPU usage and clipping are acceptable across 44.1/48/96 kHz sample rates and typical 128/256/512 buffers.

**Do not mark this version IPA-ready until native compilation, installation and AUM validation have passed.**

## V0.5 work after the V0.4 baseline

- Fixed **critical** kick-trigger bug: V0.4 started a new kick at sample 1 in every render callback.
- Introduced `Beat4BeatGate.hpp`: sample-accurate host-beat gate with state across buffers, no free-running metronome, no mid-beat resume trigger, no duplicate event at a repeated host position.
- Split sonic design: fixed transient + SONG-note sub fundamental (a new reference kick sound; listen before calling it final).
- Added portable `Beat4Layout.hpp` and changed the actual UIKit view layout to fit landscape/portrait iPhone and iPad while keeping the four bars dominant.
- Fixed absent `sub` field in stored legacy SONG dictionaries to stay unknown (`-1`) rather than silently defaulting to C.
- Extended test suite for beat seam, sample rates 44.1/48/96 kHz and multiple buffer sizes, and 8 responsive viewports; ASan/UBSan pass.
- Native GitHub Actions job builds the unsigned app and extension once the project is pushed to a **new independent repository**. The connected GitHub tool does not offer creating that repository; the existing XONE repo is intentionally untouched.

