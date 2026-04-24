#include "precompiled.hpp"
#include "gc_implementation/shared/ageTableTracer.hpp"
// JFR disabled — stub implementations
void AgeTableTracer::send_tenuring_distribution_event(uint age, size_t size, GCTracer &tracer) {}
bool AgeTableTracer::is_tenuring_distribution_event_enabled() { return false; }
