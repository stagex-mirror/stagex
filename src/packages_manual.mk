out/llvm13/index.json: \
	out/gcc/index.json \
	out/python/index.json \
	out/py-setuptools/index.json \
	out/perl/index.json \
	out/binutils/index.json \
	out/cmake/index.json \
	out/ninja/index.json \
	out/busybox/index.json \
	out/musl/index.json
	$(call build,core,llvm,13.0.1)

out/llvm/index.json: \
	out/gcc/index.json \
	out/python/index.json \
	out/py-setuptools/index.json \
	out/perl/index.json \
	out/binutils/index.json \
	out/cmake/index.json \
	out/ninja/index.json \
	out/busybox/index.json \
	out/musl/index.json
	$(call build,core,llvm)
	$(BUILDER) tag $(REGISTRY)/llvm $(REGISTRY)/llvm:16
	$(BUILDER) tag $(REGISTRY)/llvm $(REGISTRY)/llvm:16.0.6

out/rust1.54/index.json: \
	out/gcc/index.json \
	out/bash/index.json \
	out/zlib/index.json \
	out/python/index.json \
	out/py-setuptools/index.json \
	out/perl/index.json \
	out/libunwind/index.json \
	out/pkgconf/index.json \
	out/llvm13/index.json \
	out/binutils/index.json \
	out/cmake/index.json \
	out/make/index.json \
	out/busybox/index.json \
	out/musl/index.json
	$(call build,core,rust,1.54.0,bootstrap-package)

out/rust1.55/index.json: out/rust1.54/index.json
	$(call build,core,rust,1.55.0,package,--build-arg BUILD_VERSION=1.54.0)

out/rust1.56/index.json: out/rust1.55/index.json
	$(call build,core,rust,1.56.0,package,--build-arg BUILD_VERSION=1.55.0)

out/rust1.57/index.json: out/rust1.56/index.json
	$(call build,core,rust,1.57.0,package,--build-arg BUILD_VERSION=1.56.0)

out/rust1.58/index.json: out/rust1.57/index.json
	$(call build,core,rust,1.58.0,package,--build-arg BUILD_VERSION=1.57.0)

out/rust1.59/index.json: out/rust1.58/index.json
	$(call build,core,rust,1.59.0,package,--build-arg BUILD_VERSION=1.58.0)

out/rust1.60/index.json: out/rust1.59/index.json
	$(call build,core,rust,1.60.0,package,--build-arg BUILD_VERSION=1.59.0)

out/rust1.61/index.json: out/rust1.60/index.json
	$(call build,core,rust,1.61.0,package,--build-arg BUILD_VERSION=1.60.0)

out/rust1.62/index.json: out/rust1.61/index.json
	$(call build,core,rust,1.62.0,package,--build-arg BUILD_VERSION=1.61.0)

out/rust1.63/index.json: out/rust1.62/index.json
	$(call build,core,rust,1.63.0,package,--build-arg BUILD_VERSION=1.62.0)

out/rust1.64/index.json: out/rust1.63/index.json
	$(call build,core,rust,1.64.0,package,--build-arg BUILD_VERSION=1.63.0)

out/rust1.65/index.json: out/rust1.64/index.json
	$(call build,core,rust,1.65.0,package,--build-arg BUILD_VERSION=1.64.0)

out/rust1.66/index.json: out/rust1.65/index.json
	$(call build,core,rust,1.66.0,package,--build-arg BUILD_VERSION=1.65.0)

out/rust1.67/index.json: out/rust1.66/index.json
	$(call build,core,rust,1.67.0,package,--build-arg BUILD_VERSION=1.66.0)

out/rust1.68/index.json: out/rust1.67/index.json
	$(call build,core,rust,1.68.0,package,--build-arg BUILD_VERSION=1.67.0)

out/rust1.69/index.json: out/rust1.68/index.json out/llvm/index.json
	$(call build,core,rust,1.69.0,package,--build-arg BUILD_VERSION=1.68.0 --build-arg LLVM_VERSION=16)

out/rust1.70/index.json: out/rust1.69/index.json
	$(call build,core,rust,1.70.0,package,--build-arg BUILD_VERSION=1.69.0 --build-arg LLVM_VERSION=16)

out/rust1.71/index.json: out/rust1.70/index.json
	$(call build,core,rust,1.71.0,package,--build-arg BUILD_VERSION=1.70.0 --build-arg LLVM_VERSION=16)

out/rust1.72/index.json: out/rust1.71/index.json
	$(call build,core,rust,1.72.0,package,--build-arg BUILD_VERSION=1.71.0 --build-arg LLVM_VERSION=16)

out/rust1.73/index.json: out/rust1.72/index.json
	$(call build,core,rust,1.73.0,package,--build-arg BUILD_VERSION=1.72.0 --build-arg LLVM_VERSION=16)

out/rust/index.json: out/rust1.73/index.json src/core/rust/Containerfile
	$(call build,core,rust,1.74.0,package,--build-arg BUILD_VERSION=1.73.0 --build-arg LLVM_VERSION=16)

.PHONY: rust
rust: out/rust/index.json
