#pragma once
#include <atomic>
#include <array>
#include <vector>
#include <cstdint>
#include <cstddef>
namespace beat4 {
struct JournalRecord {int event,pc,origin;double beat;};
// Single render writer, bounded lock-free diagnostic storage; readers allocate only off audio thread.
template <std::size_t Capacity>
class DiagnosticRing {
 struct Slot {std::atomic<uint64_t> sequence{0};std::atomic<int> event{0},pc{-1},origin{0};std::atomic<double> beat{0};};
 std::array<Slot,Capacity> slots;
 std::atomic<uint64_t> count{0};
public:
 void write(int event,int pc,int origin,double beat) noexcept {
  const auto n=count.load(std::memory_order_relaxed);auto& s=slots[n%Capacity];
  s.sequence.store(2*n+1,std::memory_order_release);
  s.event.store(event);s.pc.store(pc);s.origin.store(origin);s.beat.store(beat);
  s.sequence.store(2*n+2,std::memory_order_release);count.store(n+1,std::memory_order_release);
 }
 std::vector<JournalRecord> read() const {
  std::vector<JournalRecord> out;const auto end=count.load(std::memory_order_acquire);
  for(auto n=end>Capacity?end-Capacity:0;n<end;++n){const auto& s=slots[n%Capacity];
   if(s.sequence.load(std::memory_order_acquire)!=2*n+2)continue;
   JournalRecord r{s.event.load(),s.pc.load(),s.origin.load(),s.beat.load()};
   if(s.sequence.load(std::memory_order_acquire)==2*n+2)out.push_back(r);
  }return out;
 }
};
using Journal = DiagnosticRing<128>;
}
