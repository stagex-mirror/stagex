#include "precompiled.hpp"
#include "gc_interface/allocTracer.hpp"
#include "runtime/handles.hpp"
#include "utilities/globalDefinitions.hpp"
// JFR disabled — stub implementations
void AllocTracer::send_allocation_outside_tlab_event(KlassHandle klass, HeapWord* obj, size_t alloc_size, Thread* thread) {}
void AllocTracer::send_allocation_in_new_tlab_event(KlassHandle klass, HeapWord* obj, size_t tlab_size, size_t alloc_size, Thread* thread) {}
void AllocTracer::send_allocation_requiring_gc_event(size_t size, const GCId& gcId) {}
