#include "../Beat4AU/Beat4Kick.hpp"
#include <cassert>
#include <cmath>
int main(){beat4::KickVoice v;v.trigger();double last=0;for(int i=0;i<5760;++i)last=v.process(48000,43.6535);v.trigger();assert(std::abs(v.process(48000,43.6535)-last)<.02);}
