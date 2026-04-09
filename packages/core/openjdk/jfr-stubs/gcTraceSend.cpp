#include "precompiled.hpp"
#include "gc_implementation/shared/gcTrace.hpp"
#include "gc_implementation/shared/gcHeapSummary.hpp"
#include "gc_implementation/shared/gcTimer.hpp"
#include "gc_implementation/shared/gcWhen.hpp"
#include "gc_implementation/shared/copyFailedInfo.hpp"
#include "runtime/os.hpp"
#if INCLUDE_ALL_GCS
#include "gc_implementation/g1/evacuationInfo.hpp"
#include "gc_implementation/g1/g1YCTypes.hpp"
#endif

// JFR disabled — all tracer functions are no-ops
typedef uintptr_t TraceAddress;

void GCTracer::send_garbage_collection_event() const {}
void GCTracer::send_reference_stats_event(ReferenceType type, size_t count) const {}
void GCTracer::send_metaspace_chunk_free_list_summary(GCWhen::Type when, Metaspace::MetadataType mdtype, const MetaspaceChunkFreeListSummary& summary) const {}
void GCTracer::send_gc_heap_summary_event(GCWhen::Type when, const GCHeapSummary& heap_summary) const {}
void GCTracer::send_meta_space_summary_event(GCWhen::Type when, const MetaspaceSummary& meta_space_summary) const {}
void GCTracer::send_phase_events(TimePartitions* time_partitions) const {}
void ParallelOldTracer::send_parallel_old_event() const {}
void YoungGCTracer::send_young_gc_event() const {}
bool YoungGCTracer::should_send_promotion_in_new_plab_event() const { return false; }
bool YoungGCTracer::should_send_promotion_outside_plab_event() const { return false; }
void YoungGCTracer::send_promotion_in_new_plab_event(Klass* klass, size_t obj_size, uint age, bool tenured, size_t plab_size) const {}
void YoungGCTracer::send_promotion_outside_plab_event(Klass* klass, size_t obj_size, uint age, bool tenured) const {}
void YoungGCTracer::send_promotion_failed_event(const PromotionFailedInfo& pf_info) const {}
void OldGCTracer::send_old_gc_event() const {}
void OldGCTracer::send_concurrent_mode_failure_event() {}
#if INCLUDE_ALL_GCS
void G1NewTracer::send_g1_young_gc_event() {}
void G1MMUTracer::send_g1_mmu_event(double time_slice_ms, double gc_time_ms, double max_time_ms) {}
void G1NewTracer::send_evacuation_info_event(EvacuationInfo* info) {}
void G1NewTracer::send_evacuation_failed_event(const EvacuationFailedInfo& ef_info) const {}
#endif
