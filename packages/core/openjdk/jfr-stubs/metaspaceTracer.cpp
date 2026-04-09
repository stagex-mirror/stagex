#include "precompiled.hpp"
#include "memory/metaspaceTracer.hpp"
// JFR disabled — stub implementations
void MetaspaceTracer::report_gc_threshold(size_t old_val, size_t new_val, MetaspaceGCThresholdUpdater::Type updater) const {}
void MetaspaceTracer::report_metaspace_allocation_failure(ClassLoaderData *cld, size_t word_size, MetaspaceObj::Type objtype, Metaspace::MetadataType mdtype) const {}
void MetaspaceTracer::report_metadata_oom(ClassLoaderData *cld, size_t word_size, MetaspaceObj::Type objtype, Metaspace::MetadataType mdtype) const {}
