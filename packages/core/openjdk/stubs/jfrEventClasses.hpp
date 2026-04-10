#ifndef _JFREVENTCLASSES_HPP
#define _JFREVENTCLASSES_HPP
// Comprehensive JFR event stubs for bootstrap build
#define S(n) template<class T> void n(T) {}
struct JfrNoopEvent {
  JfrNoopEvent() {}
  template<class A> JfrNoopEvent(A) {}
  template<class A, class B> JfrNoopEvent(A, B) {}
  bool should_commit() { return false; }
  static bool is_enabled() { return false; }
  void commit() {}
  static bool is_stacktrace_enabled() { return false; }
  int eventId() const { return 0; }
  S(set_starttime) S(set_endtime) S(set_compileId) S(set_method)
  S(set_compileLevel) S(set_inlinedBytes) S(set_codeSize) S(set_isOsr)
  S(set_succeded) S(set_succeeded) S(set_phase) S(set_phaseLevel) S(set_phaseName)
  S(set_age) S(set_size) S(set_gcId) S(set_name) S(set_when) S(set_time)
  S(set_caller) S(set_thread) S(set_objectClass) S(set_allocationSize) S(set_id)
  S(set_tlabSize) S(set_operation) S(set_safepoint) S(set_success) S(set_value)
  S(set_safepointId) S(set_totalSweepedCount) S(set_totalInvalidatedCount)
  S(set_sweepIndex) S(set_sweepFractionIndex) S(set_nmethodsCount) S(set_type)
  S(set_adaptorCount) S(set_unallocatedCapacity) S(set_fullCount) S(set_hot)
  S(set_entryCount) S(set_methodCount) S(set_codeBlobType) S(set_startAddress)
  S(set_committedTopAddress) S(set_commitedTopAddress) S(set_reservedTopAddress)
  S(set_desiredSize) S(set_oldSize) S(set_newSize) S(set_usedSize) S(set_cost)
  S(set_tenuredSize) S(set_maxAge) S(set_lived) S(set_died) S(set_totalSize)
  S(set_lockClass) S(set_previousOwner) S(set_biasedThread) S(set_revocationCount)
  S(set_disableBiasing) S(set_revokedClass) S(set_descriptor) S(set_bci) S(set_callee)
  S(set_oldValue) S(set_newValue) S(set_origin) S(set_flag) S(set_index) S(set_start)
  S(set_loadedClass) S(set_definingClassLoader) S(set_initiatingClassLoader)
  S(set_unloadedClass) S(set_address) S(set_parkedClass) S(set_result)
  S(set_timeout) S(set_monitorClass) S(set_notifier) S(set_timedOut)
  S(set_klass) S(set_classLoader) S(set_cause) S(set_message)
  S(set_edenUsedSize) S(set_edenTotalSize) S(set_survivorUsedSize)
  S(set_numberOfGCs) S(set_gcThreshold) S(set_failureMessage)
  S(set_metaspace) S(set_data) S(set_class_space) S(set_gcWhen)
  S(set_used) S(set_committed) S(set_reserved) S(set_free) S(set_count) S(set_total)
  S(set_maxMetaspaceSize) S(set_metaspaceObjectType)
  S(set_chunkFreeListHead) S(set_previousValue) S(set_total_size)
  S(set_edenSpace) S(set_fromSpace) S(set_toSpace) S(set_heapUsed)
  S(set_oldSpace) S(set_youngGen) S(set_oldGen) S(set_permGen)
  S(set_edenUsed) S(set_survivorUsed) S(set_fromUsed) S(set_toUsed)
  S(set_oldUsed) S(set_heapSpace) S(set_threshold) S(set_state)
  S(set_parentThread) S(set_deoptAction) S(set_deoptReason) S(set_inlineSize)
  S(set_hadSingleStep) S(set_stackTrace) S(set_thrownClass) S(set_from) S(set_to)
  S(set_updater) S(set_anonymousClassLoader) S(set_metadataType)
  S(set_reason) S(set_reasonAndAction) S(set_capacity) S(set_regionSize)
  S(set_usedAfter) S(set_usedBefore) S(set_heapUsedAfter) S(set_heapUsedBefore)
  S(set_totalThreadCount) S(set_jniCriticalThreadCount) S(set_initialThreadCount)
  S(set_runningThreadCount) S(set_vmOperation) S(set_synchronizationType)
  S(set_iterations) S(set_parentClassLoader) S(set_classLoaderData)
  S(set_anonymousClass) S(set_newTarget) S(set_oldTarget)
  S(set_mediumChunks) S(set_mediumChunksTotalSize)
  S(set_humongousChunks) S(set_humongousChunksTotalSize)
  S(set_smallChunks) S(set_smallChunksTotalSize) S(set_totalCount)
  S(set_specializedChunks) S(set_specializedChunksTotalSize)
  S(set_densePrefix) S(set_tenuringThreshold) S(set_gcCount) S(set_tenuringAge)
  S(set_initialSize) S(set_minSize) S(set_maxSize) S(set_usedSpace)
  S(set_freeSpace) S(set_firstSize) S(set_smallestSize) S(set_promotionFailed)
  S(set_cSetRegions) S(set_targetOccupancy) S(set_currentOccupancy)
  S(set_objectCount) S(has_stacktrace)
  S(set_flushedCount) S(set_zombifiedCount) S(set_markedForReclamationCount)
  S(set_sweepCount) S(set_methodReclaimed) S(set_sweepId) S(set_sweptCount)
  S(set_peakBlockSize) S(set_peakTotalSize) S(set_peakNmethodsCount)
  S(set_safepointStateSynchronization) S(set_eventId)
  S(set_definedClass) S(set_definingClassLoaderData) S(set_mutationCount)
  S(set_redefinitionId) S(set_classModificationCount)
  S(set_until) S(set_oop) S(set_arrayKlass) S(set_objectKlass)
  S(set_blocking) S(set_safepoint2) S(set_vmOp) S(set_eval)
};
#undef S
typedef JfrNoopEvent EventCompilerPhase;
typedef JfrNoopEvent EventCompilation;
typedef JfrNoopEvent EventTenuringDistribution;
typedef JfrNoopEvent EventObjectAllocationOutsideTLAB;
typedef JfrNoopEvent EventObjectAllocationInNewTLAB;
typedef JfrNoopEvent EventAllocationRequiringGC;
typedef JfrNoopEvent EventGCPhaseParallel;
typedef JfrNoopEvent EventGCPhasePause;
typedef JfrNoopEvent EventGCPhasePauseLevel1;
typedef JfrNoopEvent EventGCPausePauseLevel2;
typedef JfrNoopEvent EventGCPhasePauseLevel3;
typedef JfrNoopEvent EventGCPhasePauseLevel4;
typedef JfrNoopEvent EventGCPhaseConcurrent;
typedef JfrNoopEvent EventSafepointBegin;
typedef JfrNoopEvent EventSafepointEnd;
typedef JfrNoopEvent EventSafepointStateSynchronization;
typedef JfrNoopEvent EventSafepointWaitBlocked;
typedef JfrNoopEvent EventSafepointCleanup;
typedef JfrNoopEvent EventSafepointCleanupTask;
typedef JfrNoopEvent EventExecuteVMOperation;
typedef JfrNoopEvent EventSweepCodeCache;
typedef JfrNoopEvent EventCodeCacheFull;
typedef JfrNoopEvent EventCodeSweeperStatistics;
typedef JfrNoopEvent EventCodeCacheStatistics;
typedef JfrNoopEvent EventPromoteObjectOutsidePLAB;
typedef JfrNoopEvent EventPromoteObjectInNewPLAB;
typedef JfrNoopEvent EventPromotionFailed;
typedef JfrNoopEvent EventEvacuationFailed;
typedef JfrNoopEvent EventConcurrentModeFailure;
typedef JfrNoopEvent EventGarbageCollection;
typedef JfrNoopEvent EventParallelOldGarbageCollection;
typedef JfrNoopEvent EventYoungGarbageCollection;
typedef JfrNoopEvent EventOldGarbageCollection;
typedef JfrNoopEvent EventG1GarbageCollection;
typedef JfrNoopEvent EventBiasedLockSelfRevocation;
typedef JfrNoopEvent EventBiasedLockRevocation;
typedef JfrNoopEvent EventBiasedLockClassRevocation;
typedef JfrNoopEvent EventGCHeapSummary;
typedef JfrNoopEvent EventMetaspaceSummary;
typedef JfrNoopEvent EventMetaspaceGCThreshold;
typedef JfrNoopEvent EventMetaspaceAllocationFailure;
typedef JfrNoopEvent EventMetaspaceOOM;
typedef JfrNoopEvent EventMetaspaceChunkFreeListSummary;
typedef JfrNoopEvent EventPSHeapSummary;
typedef JfrNoopEvent EventG1HeapSummary;
typedef JfrNoopEvent EventGCPermGenSummary;
typedef JfrNoopEvent EventGCPhasePauseLevel2;
typedef JfrNoopEvent EventThreadPark;
typedef JfrNoopEvent EventThreadSleep;
typedef JfrNoopEvent EventJavaMonitorEnter;
typedef JfrNoopEvent EventJavaMonitorWait;
typedef JfrNoopEvent EventJavaMonitorInflate;
typedef JfrNoopEvent EventClassLoad;
typedef JfrNoopEvent EventClassUnload;
typedef JfrNoopEvent EventLongFlagChanged;
typedef JfrNoopEvent EventUnsignedLongFlagChanged;
typedef JfrNoopEvent EventDoubleFlagChanged;
typedef JfrNoopEvent EventBooleanFlagChanged;
typedef JfrNoopEvent EventStringFlagChanged;
typedef JfrNoopEvent EventUnsignedIntFlagChanged;
typedef JfrNoopEvent EventIntFlagChanged;
typedef JfrNoopEvent EventVMError;
typedef JfrNoopEvent EventCompilerInlining;
typedef JfrNoopEvent JfrStructCalleeMethod;
typedef JfrNoopEvent EventG1HeapRegionInformation;
typedef JfrNoopEvent EventEvacuationInformation;
typedef JfrNoopEvent EventG1HeapRegionTypeChange;
typedef JfrNoopEvent EventG1BasicIHOP;
typedef JfrNoopEvent EventG1AdaptiveIHOP;
typedef JfrNoopEvent EventG1MMU;
typedef JfrNoopEvent EventG1EvacuationYoungStatistics;
typedef JfrNoopEvent EventG1EvacuationOldStatistics;
typedef JfrNoopEvent EventCompilationFailure;
typedef JfrNoopEvent EventDeoptimization;
typedef JfrNoopEvent EventG1HeapRegionTypeChangeInfo;
typedef JfrNoopEvent EventThreadEnd;
typedef JfrNoopEvent EventThreadStart;
typedef JfrNoopEvent EventVMOperation;
typedef JfrNoopEvent EventObjectCountAfterGC;
typedef JfrNoopEvent EventGCConfiguration;
typedef JfrNoopEvent EventGCSurvivorConfiguration;
typedef JfrNoopEvent EventGCTLABConfiguration;
typedef JfrNoopEvent EventGCHeapConfiguration;
typedef JfrNoopEvent EventGCNewConfiguration;
typedef JfrNoopEvent EventGCOldConfiguration;
typedef JfrNoopEvent EventG1EvacuationYoungConfig;
typedef JfrNoopEvent EventG1EvacuationOldConfig;
typedef JfrNoopEvent EventJavaExceptionThrow;
typedef JfrNoopEvent EventJavaErrorThrow;
typedef JfrNoopEvent EventNativeMethodSample;
typedef JfrNoopEvent EventThreadDump;
typedef JfrNoopEvent EventOSInformation;
typedef JfrNoopEvent EventCPUInformation;
typedef JfrNoopEvent EventCPULoad;
typedef JfrNoopEvent EventThreadCPULoad;
typedef JfrNoopEvent EventThreadAllocationStatistics;
typedef JfrNoopEvent EventPhysicalMemory;
typedef JfrNoopEvent EventJavaThreadStatistics;
typedef JfrNoopEvent EventClassLoadingStatistics;
typedef JfrNoopEvent EventClassLoaderStatistics;
typedef JfrNoopEvent EventCompilerConfiguration;
typedef JfrNoopEvent EventCompilerStatistics;
typedef JfrNoopEvent EventSystemProcess;
typedef JfrNoopEvent EventGCReferenceStatistics;
typedef JfrNoopEvent EventShutdown;
template<class T> struct JfrConditionalFlushWithStacktrace {
  JfrConditionalFlushWithStacktrace(void*) {}
};
template<class T> struct JfrConditionalFlush {
  JfrConditionalFlush(void*) {}
};
typedef JfrNoopEvent EventClassDefine;
typedef JfrNoopEvent EventRedefineClasses;
typedef JfrNoopEvent EventRetransformClasses;
typedef JfrNoopEvent EventObjectCount;
typedef JfrNoopEvent EventGCHeapConfiguration;
typedef JfrNoopEvent EventYoungGenerationConfiguration;
struct JfrStackTraceRepository {
  static void record_and_cache(void*, int) {}
  template<class T> static int record(T, int n=0) { return 0; }
};
// JFR struct stubs used by GC tracers
struct JfrStructCopyFailed {
  void set_objectCount(unsigned long) {}
  void set_firstSize(unsigned long) {}
  void set_smallestSize(unsigned long) {}
  void set_totalSize(unsigned long) {}
};
struct JfrStructVirtualSpace {
  void set_start(unsigned long) {}
  void set_committedEnd(unsigned long) {}
  void set_committedSize(unsigned long) {}
  void set_reservedEnd(unsigned long) {}
  void set_reservedSize(unsigned long) {}
};
struct JfrStructObjectSpace {
  void set_start(unsigned long) {}
  void set_end(unsigned long) {}
  void set_used(unsigned long) {}
  void set_size(unsigned long) {}
};
struct JfrStructGCLazyRelocationSet : JfrStructCopyFailed {};
#endif
