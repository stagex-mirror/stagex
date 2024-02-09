out/llvm13.digest: \
	out/gcc.digest \
	out/python.digest \
	out/py-setuptools.digest \
	out/perl.digest \
	out/binutils.digest \
	out/cmake.digest \
	out/ninja.digest \
	out/busybox.digest \
	out/musl.digest
	$(call build,core,llvm,13.0.1)

out/llvm.digest: \
	out/gcc.digest \
	out/python.digest \
	out/py-setuptools.digest \
	out/perl.digest \
	out/binutils.digest \
	out/cmake.digest \
	out/ninja.digest \
	out/busybox.digest \
	out/musl.digest
	$(call build,core,llvm)
	$(BUILDER) tag $(REGISTRY)/llvm $(REGISTRY)/llvm:16
	$(BUILDER) tag $(REGISTRY)/llvm $(REGISTRY)/llvm:16.0.6

out/rust1.54.digest: \
	out/gcc.digest \
	out/bash.digest \
	out/zlib.digest \
	out/python.digest \
	out/py-setuptools.digest \
	out/perl.digest \
	out/libunwind.digest \
	out/pkgconf.digest \
	out/llvm13.digest \
	out/binutils.digest \
	out/cmake.digest \
	out/make.digest \
	out/busybox.digest \
	out/musl.digest
	$(call build,core,rust,1.54.0,bootstrap-package)

out/rust1.55.digest: out/rust1.54.digest
	$(call build,core,rust,1.55.0,package,--build-arg BUILD_VERSION=1.54.0)

out/rust1.56.digest: out/rust1.55.digest
	$(call build,core,rust,1.56.0,package,--build-arg BUILD_VERSION=1.55.0)

out/rust1.57.digest: out/rust1.56.digest
	$(call build,core,rust,1.57.0,package,--build-arg BUILD_VERSION=1.56.0)

out/rust1.58.digest: out/rust1.57.digest
	$(call build,core,rust,1.58.0,package,--build-arg BUILD_VERSION=1.57.0)

out/rust1.59.digest: out/rust1.58.digest
	$(call build,core,rust,1.59.0,package,--build-arg BUILD_VERSION=1.58.0)

out/rust1.60.digest: out/rust1.59.digest
	$(call build,core,rust,1.60.0,package,--build-arg BUILD_VERSION=1.59.0)

out/rust1.61.digest: out/rust1.60.digest
	$(call build,core,rust,1.61.0,package,--build-arg BUILD_VERSION=1.60.0)

out/rust1.62.digest: out/rust1.61.digest
	$(call build,core,rust,1.62.0,package,--build-arg BUILD_VERSION=1.61.0)

out/rust1.63.digest: out/rust1.62.digest
	$(call build,core,rust,1.63.0,package,--build-arg BUILD_VERSION=1.62.0)

out/rust1.64.digest: out/rust1.63.digest
	$(call build,core,rust,1.64.0,package,--build-arg BUILD_VERSION=1.63.0)

out/rust1.65.digest: out/rust1.64.digest
	$(call build,core,rust,1.65.0,package,--build-arg BUILD_VERSION=1.64.0)

out/rust1.66.digest: out/rust1.65.digest
	$(call build,core,rust,1.66.0,package,--build-arg BUILD_VERSION=1.65.0)

out/rust1.67.digest: out/rust1.66.digest
	$(call build,core,rust,1.67.0,package,--build-arg BUILD_VERSION=1.66.0)

out/rust1.68.digest: out/rust1.67.digest
	$(call build,core,rust,1.68.0,package,--build-arg BUILD_VERSION=1.67.0)

out/rust1.69.digest: out/rust1.68.digest out/llvm.digest
	$(call build,core,rust,1.69.0,package,--build-arg BUILD_VERSION=1.68.0 --build-arg LLVM_VERSION=16)

out/rust1.70.digest: out/rust1.69.digest
	$(call build,core,rust,1.70.0,package,--build-arg BUILD_VERSION=1.69.0 --build-arg LLVM_VERSION=16)

out/rust1.71.digest: out/rust1.70.digest
	$(call build,core,rust,1.71.0,package,--build-arg BUILD_VERSION=1.70.0 --build-arg LLVM_VERSION=16)

out/rust1.72.digest: out/rust1.71.digest
	$(call build,core,rust,1.72.0,package,--build-arg BUILD_VERSION=1.71.0 --build-arg LLVM_VERSION=16)

out/rust1.73.digest: out/rust1.72.digest
	$(call build,core,rust,1.73.0,package,--build-arg BUILD_VERSION=1.72.0 --build-arg LLVM_VERSION=16)

out/rust.digest: out/rust1.73.digest src/core/rust/Containerfile
	$(call build,core,rust,1.74.0,package,--build-arg BUILD_VERSION=1.73.0 --build-arg LLVM_VERSION=16)

.PHONY: rust
rust: out/rust.digest
