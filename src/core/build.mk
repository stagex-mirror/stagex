.PHONY: core
core: \
	out/rust.tar \
	out/go.tar \
	out/python.tar \
	out/perl.tar \
	out/gcc.tar \
	out/llvm.tar

out/musl.tar: out/stage3.tar
	$(call build,core,musl)

out/busybox.tar: out/stage3.tar
	$(call build,core,busybox)

out/binutils.tar: out/stage3.tar out/musl.tar
	$(call build,core,binutils)

out/make.tar: out/stage3.tar
	$(call build,core,make)

out/gcc.tar: out/stage3.tar out/binutils.tar out/musl.tar
	$(call build,core,gcc)

out/bash.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,bash)

out/m4.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,m4)

out/perl.tar: \
	out/gcc.tar \
	out/binutils.tar \
	out/busybox.tar \
	out/make.tar \
	out/musl.tar
	$(call build,core,perl)

out/autoconf.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/perl.tar \
	out/m4.tar
	$(call build,core,autoconf,,fetch)
	$(call build,core,autoconf)

out/automake.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/perl.tar \
	out/autoconf.tar \
	out/m4.tar
	$(call build,core,automake)

out/sed.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,sed)

out/libtool.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/bash.tar \
	out/sed.tar \
	out/m4.tar
	$(call build,core,libtool)

out/pkgconf.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/libtool.tar
	$(call build,core,pkgconf)

out/libunwind.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/bash.tar \
	out/autoconf.tar \
	out/automake.tar \
	out/libtool.tar
	$(call build,core,libunwind)

out/linux-headers.tar:
	$(call build,core,linux-headers)

out/openssl.tar: \
	out/gcc.tar \
	out/binutils.tar \
	out/busybox.tar \
	out/linux-headers.tar \
	out/musl.tar
	$(call build,core,openssl)

out/go.tar: \
	out/gcc.tar \
	out/binutils.tar \
	out/busybox.tar \
	out/bash.tar \
	out/musl.tar
	$(call build,core,go)

out/python.tar: \
	out/gcc.tar \
	out/perl.tar \
	out/binutils.tar \
	out/busybox.tar \
	out/openssl.tar \
	out/zlib.tar \
	out/make.tar \
	out/musl.tar
	$(call build,core,python)

out/ninja.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/openssl.tar \
	out/python.tar
	$(call build,core,ninja)

out/cmake.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/ninja.tar \
	out/musl.tar \
	out/make.tar \
	out/linux-headers.tar
	$(call build,core,cmake)

out/py-setuptools.tar: \
	out/busybox.tar \
	out/python.tar \
	out/zlib.tar
	$(call build,core,py-setuptools)

out/zlib.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,zlib)

out/llvm13.tar: \
	out/gcc.tar \
	out/python.tar \
	out/py-setuptools.tar \
	out/perl.tar \
	out/binutils.tar \
	out/cmake.tar \
	out/ninja.tar \
	out/busybox.tar \
	out/zlib.tar \
	out/musl.tar
	$(call build,core,llvm,13.0.1)

out/llvm.tar: \
	out/gcc.tar \
	out/python.tar \
	out/py-setuptools.tar \
	out/perl.tar \
	out/binutils.tar \
	out/cmake.tar \
	out/ninja.tar \
	out/busybox.tar \
	out/zlib.tar \
	out/musl.tar
	$(call build,core,llvm)
	$(BUILDER) tag $(REGISTRY)/llvm $(REGISTRY)/llvm:16
	$(BUILDER) tag $(REGISTRY)/llvm $(REGISTRY)/llvm:16.0.6

out/rust1.54.tar: \
	out/gcc.tar \
	out/bash.tar \
	out/zlib.tar \
	out/python.tar \
	out/py-setuptools.tar \
	out/perl.tar \
	out/libunwind.tar \
	out/pkgconf.tar \
	out/llvm13.tar \
	out/binutils.tar \
	out/cmake.tar \
	out/make.tar \
	out/busybox.tar \
	out/musl.tar
	$(call build,core,rust,1.54.0,bootstrap-package)

out/rust1.55.tar: out/rust1.54.tar
	$(call build,core,rust,1.55.0,package,--build-arg BUILD_VERSION=1.54.0)

out/rust1.56.tar: out/rust1.55.tar
	$(call build,core,rust,1.56.0,package,--build-arg BUILD_VERSION=1.55.0)

out/rust1.57.tar: out/rust1.56.tar
	$(call build,core,rust,1.57.0,package,--build-arg BUILD_VERSION=1.56.0)

out/rust1.58.tar: out/rust1.57.tar
	$(call build,core,rust,1.58.0,package,--build-arg BUILD_VERSION=1.57.0)

out/rust1.59.tar: out/rust1.58.tar
	$(call build,core,rust,1.59.0,package,--build-arg BUILD_VERSION=1.58.0)

out/rust1.60.tar: out/rust1.59.tar
	$(call build,core,rust,1.60.0,package,--build-arg BUILD_VERSION=1.59.0)

out/rust1.61.tar: out/rust1.60.tar
	$(call build,core,rust,1.61.0,package,--build-arg BUILD_VERSION=1.60.0)

out/rust1.62.tar: out/rust1.61.tar
	$(call build,core,rust,1.62.0,package,--build-arg BUILD_VERSION=1.61.0)

out/rust1.63.tar: out/rust1.62.tar
	$(call build,core,rust,1.63.0,package,--build-arg BUILD_VERSION=1.62.0)

out/rust1.64.tar: out/rust1.63.tar
	$(call build,core,rust,1.64.0,package,--build-arg BUILD_VERSION=1.63.0)

out/rust1.65.tar: out/rust1.64.tar
	$(call build,core,rust,1.65.0,package,--build-arg BUILD_VERSION=1.64.0)

out/rust1.66.tar: out/rust1.65.tar
	$(call build,core,rust,1.66.0,package,--build-arg BUILD_VERSION=1.65.0)

out/rust1.67.tar: out/rust1.66.tar
	$(call build,core,rust,1.67.0,package,--build-arg BUILD_VERSION=1.66.0)

out/rust1.68.tar: out/rust1.67.tar
	$(call build,core,rust,1.68.0,package,--build-arg BUILD_VERSION=1.67.0)

out/rust1.69.tar: out/rust1.68.tar out/llvm.tar
	$(call build,core,rust,1.69.0,package,--build-arg BUILD_VERSION=1.68.0 --build-arg LLVM_VERSION=16)

out/rust1.70.tar: out/rust1.69.tar
	$(call build,core,rust,1.70.0,package,--build-arg BUILD_VERSION=1.69.0 --build-arg LLVM_VERSION=16)

out/rust1.71.tar: out/rust1.70.tar
	$(call build,core,rust,1.71.0,package,--build-arg BUILD_VERSION=1.70.0 --build-arg LLVM_VERSION=16)

out/rust1.72.tar: out/rust1.71.tar
	$(call build,core,rust,1.72.0,package,--build-arg BUILD_VERSION=1.71.0 --build-arg LLVM_VERSION=16)

out/rust1.73.tar: out/rust1.72.tar
	$(call build,core,rust,1.73.0,package,--build-arg BUILD_VERSION=1.72.0 --build-arg LLVM_VERSION=16)

out/rust.tar: out/rust1.73.tar
	$(call build,core,rust,1.74.0,package,--build-arg BUILD_VERSION=1.73.0 --build-arg LLVM_VERSION=16)

out/bison.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,bison)

out/gettext.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,gettext)

out/flex.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/autoconf.tar \
	out/libtool.tar \
	out/binutils.tar \
	out/gettext.tar \
	out/bison.tar \
	out/musl.tar \
	out/make.tar
	$(call build,core,flex)

out/argp-standalone.tar: \
	out/libtool.tar \
	out/automake.tar \
	out/autoconf.tar \
	out/make.tar \
	out/musl.tar \
	out/m4.tar \
	out/gcc.tar
	$(call build,core,argp-standalone)

out/musl-fts.tar: \
	out/libtool.tar \
	out/automake.tar \
	out/autoconf.tar \
	out/make.tar \
	out/musl.tar \
	out/m4.tar \
	out/pkgconf.tar \
	out/gcc.tar
	$(call build,core,musl-fts)

out/musl-obstack.tar: \
	out/libtool.tar \
	out/automake.tar \
	out/autoconf.tar \
	out/make.tar \
	out/musl.tar \
	out/m4.tar \
	out/pkgconf.tar \
	out/gcc.tar
	$(call build,core,musl-obstack)

out/meson.tar: \
	out/busybox.tar \
	out/cmake.tar \
	out/llvm.tar \
	out/python.tar \
	out/py-setuptools.tar \
	out/linux-headers.tar \
	out/zlib.tar
	$(call build,core,meson)

out/libzstd.tar: \
	out/busybox.tar \
	out/meson.tar \
	out/python.tar \
	out/zlib.tar
	$(call build,core,libzstd)

out/elfutils.tar: \
	out/busybox.tar \
	out/argp-standalone.tar \
	out/musl.tar \
	out/musl-fts.tar \
	out/musl-obstack.tar \
	out/binutils.tar \
	out/bison.tar \
	out/flex.tar \
	out/linux-headers.tar \
	out/libtool.tar \
	out/gettext.tar \
	out/libzstd.tar \
	out/pkgconf.tar \
	out/autoconf.tar \
	out/automake.tar \
	out/m4.tar \
	out/make.tar \
	out/gcc.tar \
	out/zlib.tar
	$(call build,core,elfutils)
