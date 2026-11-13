#include "../Beat4AU/Beat4Layout.hpp"
#include <cassert>
#include <cmath>
int main(){
 auto c=beat4::layoutFor(667,375);
 // Published R02 compact bars: four 72pt bars at 150pt pitch, y68 height177.
 assert(std::abs(c.bars.y-68)<.001);
 assert(std::abs(c.bars.h-177)<.001);
 assert(c.toggle.x<c.song.x);
 auto p=beat4::layoutFor(390,844);
 assert(p.levelLabel.y>p.kick.y+20);
 assert(p.toggle.x<p.song.x);
}
