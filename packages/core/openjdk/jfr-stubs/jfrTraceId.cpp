#include "precompiled.hpp"
#include "jfr/recorder/checkpoint/types/traceid/jfrTraceId.hpp"
// JFR disabled — stub

void JfrTraceId::assign(const Klass*) {}
void JfrTraceId::assign(const ClassLoaderData*) {}
void JfrTraceId::remove(const Klass*) {}
void JfrTraceId::restore(const Klass*) {}
traceid JfrTraceId::assign_primitive_klass_id() { return 0; }
