#include "precompiled.hpp"
#include "jfr/jfr.hpp"

// ===== Jfr core API stubs =====
bool Jfr::is_enabled() { return false; }
bool Jfr::is_disabled() { return true; }
bool Jfr::is_recording() { return false; }
void Jfr::on_vm_init() {}
void Jfr::on_vm_start() {}
void Jfr::on_unloading_classes() {}
void Jfr::on_thread_start(Thread*) {}
void Jfr::on_thread_exit(Thread*) {}
void Jfr::on_java_thread_dismantle(JavaThread*) {}
void Jfr::on_vm_shutdown(bool) {}
bool Jfr::on_flight_recorder_option(const JavaVMOption**, char*) { return false; }
bool Jfr::on_start_flight_recording_option(const JavaVMOption**, char*) { return false; }
void Jfr::weak_oops_do(BoolObjectClosure*, OopClosure*) {}
void Jfr::weak_oops_do(OopClosure*) {}
Thread* Jfr::sampler_thread() { return 0; }
extern "C" void JNICALL jfr_register_natives(JNIEnv*, jclass) {}
