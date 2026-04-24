#include "precompiled.hpp"
#include "jfr/utilities/jfrAllocation.hpp"
// JFR disabled — stub

void JfrCHeapObj::operator delete(void* p, size_t) { ::free(p); }
