#include "../Beat4AU/Beat4BPMGesture.hpp"
#include <cassert>
#include <cmath>
int main(){assert(beat4::initialDraggedBPM(0,0)==120);assert(beat4::initialDraggedBPM(135,128)==135);assert(beat4::draggedBPM(120,36)==129);assert(beat4::draggedBPM(120,-36)==111);assert(beat4::draggedBPM(120,3.9)==120);assert(beat4::draggedBPM(120,NAN)==120);}
