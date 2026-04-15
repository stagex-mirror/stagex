## AMDGPU TableGen Bugs (CURRENT ISSUE - 4/13/2026)

**Status**: BLOCKED - LLVM 21.1.8 amd-mainline branch has multiple TableGen bugs

**Bugs Found**:

1. **HwMode Features field error** (FIXED with patch):
   - Error: "Record `AVAlign2LoadStoreMode' does not have a field named `Features'!"
   - Fix: Added `string Features = "";` to HwMode class in Target.td
   - Patch: `packages/user/rocm-llvm/patches/hwmode-features-field.patch`

2. **IIT_RetNumbers list error** (UNFIXED):
   - Error: "error: unable to find 'IIT_RetNumbers' list"
   - Location: AMDGPU.td TableGen processing
   - Status: No known fix - requires upstream LLVM patch
   - This bug prevents AMDGPU backend from building

**Root Cause**: The llvm-project.tar.gz updated on Apr 12 23:25 contains LLVM 21.1.8 from amd-mainline branch with these TableGen bugs.

**Workarounds**:

1. **Use cached working image** (RECOMMENDED):
   - Build log: `log-rocm-build75` (DONE 95.8s)
   - This build used a previously cached rocm-llvm image that doesn't have these bugs
   - The cached image was built before Apr 12 when the llvm-project.tar.gz was updated

2. **Wait for upstream fixes**:
   - These bugs need to be fixed in LLVM upstream
   - Check https://github.com/llvm/llvm-project for AMDGPU TableGen fixes

3. **Use older LLVM version**:
   - Downgrade to an earlier LLVM version that doesn't have these bugs
   - May require updating llvm-project.tar.gz to an older commit

**Files Modified**:
- `packages/user/rocm-llvm/patches/hwmode-features-field.patch` - Fixes HwMode Features field
- `packages/user/rocm-llvm/Containerfile` - Applies the patch

**Current Build Status**:
- HwMode Features patch applied successfully
- IIT_RetNumbers bug blocks AMDGPU backend build
- Build fails at stage #23 (llvm-build) when processing AMDGPU.td

**Next Steps**:
- Use the cached working rocm-llvm image from log-rocm-build75
- Or wait for upstream LLVM fixes for IIT_RetNumbers bug
- Or downgrade to older LLVM version without these bugs
