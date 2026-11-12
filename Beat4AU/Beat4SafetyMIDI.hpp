#pragma once
#include <atomic>
namespace beat4 {
inline int safetyCC(int command) noexcept {return command==2?110:(command==1?111:-1);}
inline bool useMMC(int command,bool safety) noexcept {return !safety || command==9 || command==5;}
struct CCPulse {int cc=-1; int value=0;};
// UI publishes latest intent, render owns the release. A release is never lost
// to a following press. No allocation, MIDI is emitted only by the render thread.
class SafetyPulse {
public:
    void request(int command) noexcept {if(safetyCC(command)>=0)pending_.store(command,std::memory_order_release);}
    CCPulse next() noexcept {
        if(release_>=0){const int cc=release_;release_=-1;return {cc,0};}
        const int cc=safetyCC(pending_.exchange(0,std::memory_order_acq_rel));
        if(cc<0)return {};
        release_=cc;return {cc,127};
    }
    void cancelPending() noexcept {pending_.store(0,std::memory_order_release);}
    void reset() noexcept {cancelPending();release_=-1;}
private:
    std::atomic<int> pending_{0};
    int release_=-1;
};
}
