src/packages.mk: src/packages.sh
	src/packages.sh > src/packages.mk

PHONY: stage0
stage0: out/stage0.digest
out/stage0.digest: \
	src/bootstrap/stage0/Containerfile
	$(call build,bootstrap,stage0)

PHONY: stage1
stage1: out/stage1.digest
out/stage1.digest: \
	src/bootstrap/stage1/Containerfile \
	stage0
	$(call build,bootstrap,stage1)

PHONY: stage2
stage2: out/stage2.digest
out/stage2.digest: \
	src/bootstrap/stage2/Containerfile \
	stage1
	$(call build,bootstrap,stage2)

PHONY: stage3
stage3: out/stage3.digest
out/stage3.digest: \
	src/bootstrap/stage3/Containerfile \
	stage2
	$(call build,bootstrap,stage3)

PHONY: argp-standalone
argp-standalone: out/argp-standalone.digest
out/argp-standalone.digest: \
	src/core/argp-standalone/Containerfile \
	autoconf \
	automake \
	binutils \
	busybox \
	gcc \
	m4 \
	make \
	musl
	$(call build,core,argp-standalone)

PHONY: autoconf
autoconf: out/autoconf.digest
out/autoconf.digest: \
	src/core/autoconf/Containerfile \
	binutils \
	busybox \
	gcc \
	m4 \
	make \
	musl \
	perl
	$(call build,core,autoconf)

PHONY: automake
automake: out/automake.digest
out/automake.digest: \
	src/core/automake/Containerfile \
	autoconf \
	binutils \
	busybox \
	gcc \
	m4 \
	make \
	musl \
	perl
	$(call build,core,automake)

PHONY: bash
bash: out/bash.digest
out/bash.digest: \
	src/core/bash/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,bash)

PHONY: binutils
binutils: out/binutils.digest
out/binutils.digest: \
	src/core/binutils/Containerfile \
	stage3
	$(call build,core,binutils)

PHONY: bison
bison: out/bison.digest
out/bison.digest: \
	src/core/bison/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,bison)

PHONY: busybox
busybox: out/busybox.digest
out/busybox.digest: \
	src/core/busybox/Containerfile \
	stage3
	$(call build,core,busybox)

PHONY: cmake
cmake: out/cmake.digest
out/cmake.digest: \
	src/core/cmake/Containerfile \
	binutils \
	busybox \
	gcc \
	linux-headers \
	make \
	musl \
	ninja \
	openssl
	$(call build,core,cmake)

PHONY: elfutils
elfutils: out/elfutils.digest
out/elfutils.digest: \
	src/core/elfutils/Containerfile \
	argp-standalone \
	autoconf \
	automake \
	binutils \
	bison \
	busybox \
	flex \
	gcc \
	gettext \
	libtool \
	libzstd \
	linux-headers \
	m4 \
	make \
	musl \
	musl-fts \
	musl-obstack \
	pkgconf \
	zlib
	$(call build,core,elfutils)

PHONY: flex
flex: out/flex.digest
out/flex.digest: \
	src/core/flex/Containerfile \
	autoconf \
	automake \
	binutils \
	bison \
	busybox \
	gcc \
	gettext \
	libtool \
	m4 \
	make \
	musl
	$(call build,core,flex)

PHONY: gcc
gcc: out/gcc.digest
out/gcc.digest: \
	src/core/gcc/Containerfile \
	stage3 \
	binutils \
	busybox \
	musl
	$(call build,core,gcc)

PHONY: gettext
gettext: out/gettext.digest
out/gettext.digest: \
	src/core/gettext/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,gettext)

PHONY: go
go: out/go.digest
out/go.digest: \
	src/core/go/Containerfile \
	bash \
	binutils \
	busybox \
	gcc \
	musl
	$(call build,core,go)

PHONY: libtool
libtool: out/libtool.digest
out/libtool.digest: \
	src/core/libtool/Containerfile \
	binutils \
	busybox \
	gcc \
	m4 \
	make \
	musl
	$(call build,core,libtool)

PHONY: libunwind
libunwind: out/libunwind.digest
out/libunwind.digest: \
	src/core/libunwind/Containerfile \
	autoconf \
	automake \
	binutils \
	busybox \
	gcc \
	libtool \
	make \
	musl
	$(call build,core,libunwind)

PHONY: libzstd
libzstd: out/libzstd.digest
out/libzstd.digest: \
	src/core/libzstd/Containerfile \
	binutils \
	busybox \
	gcc \
	meson \
	musl \
	ninja \
	pkgconf \
	python \
	zlib
	$(call build,core,libzstd)

PHONY: linux-headers
linux-headers: out/linux-headers.digest
out/linux-headers.digest: \
	src/core/linux-headers/Containerfile \
	stage3
	$(call build,core,linux-headers)

PHONY: m4
m4: out/m4.digest
out/m4.digest: \
	src/core/m4/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,m4)

PHONY: make
make: out/make.digest
out/make.digest: \
	src/core/make/Containerfile \
	stage3
	$(call build,core,make)

PHONY: meson
meson: out/meson.digest
out/meson.digest: \
	src/core/meson/Containerfile \
	busybox \
	py-setuptools \
	python \
	zlib
	$(call build,core,meson)

PHONY: musl
musl: out/musl.digest
out/musl.digest: \
	src/core/musl/Containerfile \
	stage3
	$(call build,core,musl)

PHONY: musl-fts
musl-fts: out/musl-fts.digest
out/musl-fts.digest: \
	src/core/musl-fts/Containerfile \
	autoconf \
	automake \
	binutils \
	busybox \
	gcc \
	libtool \
	m4 \
	make \
	musl \
	pkgconf
	$(call build,core,musl-fts)

PHONY: musl-obstack
musl-obstack: out/musl-obstack.digest
out/musl-obstack.digest: \
	src/core/musl-obstack/Containerfile \
	autoconf \
	automake \
	binutils \
	busybox \
	gcc \
	libtool \
	m4 \
	make \
	musl \
	pkgconf
	$(call build,core,musl-obstack)

PHONY: ninja
ninja: out/ninja.digest
out/ninja.digest: \
	src/core/ninja/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl \
	openssl \
	python
	$(call build,core,ninja)

PHONY: openssl
openssl: out/openssl.digest
out/openssl.digest: \
	src/core/openssl/Containerfile \
	binutils \
	busybox \
	gcc \
	linux-headers \
	make \
	musl \
	perl
	$(call build,core,openssl)

PHONY: perl
perl: out/perl.digest
out/perl.digest: \
	src/core/perl/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,perl)

PHONY: pkgconf
pkgconf: out/pkgconf.digest
out/pkgconf.digest: \
	src/core/pkgconf/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,pkgconf)

PHONY: py-setuptools
py-setuptools: out/py-setuptools.digest
out/py-setuptools.digest: \
	src/core/py-setuptools/Containerfile \
	busybox \
	python \
	zlib
	$(call build,core,py-setuptools)

PHONY: python
python: out/python.digest
out/python.digest: \
	src/core/python/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl \
	openssl \
	zlib
	$(call build,core,python)

PHONY: sed
sed: out/sed.digest
out/sed.digest: \
	src/core/sed/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,sed)

PHONY: zlib
zlib: out/zlib.digest
out/zlib.digest: \
	src/core/zlib/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,zlib)

PHONY: linux-generic
linux-generic: out/linux-generic.digest
out/linux-generic.digest: \
	src/kernel/linux-generic/Containerfile \
	binutils \
	bison \
	busybox \
	elfutils \
	flex \
	gcc \
	libzstd \
	linux-headers \
	m4 \
	make \
	musl \
	openssl \
	perl \
	pkgconf \
	zlib
	$(call build,kernel,linux-generic)

PHONY: ca-certificates
ca-certificates: out/ca-certificates.digest
out/ca-certificates.digest: \
	src/libs/ca-certificates/Containerfile \
	busybox
	$(call build,libs,ca-certificates)

PHONY: libxml2
libxml2: out/libxml2.digest
out/libxml2.digest: \
	src/libs/libxml2/Containerfile \
	autoconf \
	automake \
	binutils \
	busybox \
	gcc \
	libtool \
	m4 \
	make \
	musl \
	pkgconf \
	python
	$(call build,libs,libxml2)

PHONY: cpio
cpio: out/cpio.digest
out/cpio.digest: \
	src/tools/cpio/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,tools,cpio)

PHONY: curl
curl: out/curl.digest
out/curl.digest: \
	src/tools/curl/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl \
	openssl
	$(call build,tools,curl)

PHONY: gen_initramfs
gen_initramfs: out/gen_initramfs.digest
out/gen_initramfs.digest: \
	src/tools/gen_initramfs/Containerfile \
	binutils \
	busybox \
	gcc \
	musl
	$(call build,tools,gen_initramfs)

PHONY: sops
sops: out/sops.digest
out/sops.digest: \
	src/tools/sops/Containerfile \
	busybox \
	go \
	ca-certificates
	$(call build,tools,sops)

PHONY: tofu
tofu: out/tofu.digest
out/tofu.digest: \
	src/tools/tofu/Containerfile \
	busybox \
	go \
	ca-certificates
	$(call build,tools,tofu)

