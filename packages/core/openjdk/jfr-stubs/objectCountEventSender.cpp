#include "precompiled.hpp"
#include "gc_implementation/shared/objectCountEventSender.hpp"
// JFR disabled — stub implementations
bool ObjectCountEventSender::_should_send_requestable_event = false;
void ObjectCountEventSender::enable_requestable_event() {}
void ObjectCountEventSender::disable_requestable_event() {}
void ObjectCountEventSender::send(const KlassInfoEntry* entry, GCId gc_id, const Ticks& timestamp) {}
bool ObjectCountEventSender::should_send_event() { return false; }
