#include "../Beat4AU/Beat4Journal.hpp"
#include <cassert>
int main(){beat4::Journal j;for(int i=0;i<150;++i)j.write(1,i,3,i*.5);auto r=j.read();assert(r.size()==128 && r.front().pc==22 && r.back().beat==74.5);}
