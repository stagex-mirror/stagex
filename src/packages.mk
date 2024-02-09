src/packages.mk: src/packages.sh
	src/packages.sh > src/packages.mk

PHONY: stage0
stage0: out/stage0/index.json
out/stage0/index.json: \
	src/bootstrap/stage0/Containerfile
	$(call build,bootstrap,stage0)

PHONY: stage1
stage1: out/stage1/index.json
out/stage1/index.json: \
	src/bootstrap/stage1/Containerfile \
	stage0
	$(call build,bootstrap,stage1)

PHONY: stage2
stage2: out/stage2/index.json
out/stage2/index.json: \
	src/bootstrap/stage2/Containerfile \
	stage1
	$(call build,bootstrap,stage2)

PHONY: stage3
stage3: out/stage3/index.json
out/stage3/index.json: \
	src/bootstrap/stage3/Containerfile \
	stage2
	$(call build,bootstrap,stage3)

PHONY: argp-standalone
argp-standalone: out/argp-standalone/index.json
out/argp-standalone/index.json: \
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
autoconf: out/autoconf/index.json
out/autoconf/index.json: \
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
automake: out/automake/index.json
out/automake/index.json: \
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
bash: out/bash/index.json
out/bash/index.json: \
	src/core/bash/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,bash)

PHONY: binutils
binutils: out/binutils/index.json
out/binutils/index.json: \
	src/core/binutils/Containerfile \
	stage3
	$(call build,core,binutils)

PHONY: bison
bison: out/bison/index.json
out/bison/index.json: \
	src/core/bison/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,bison)

PHONY: busybox
busybox: out/busybox/index.json
out/busybox/index.json: \
	src/core/busybox/Containerfile \
	stage3
	$(call build,core,busybox)

PHONY: cmake
cmake: out/cmake/index.json
out/cmake/index.json: \
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
elfutils: out/elfutils/index.json
out/elfutils/index.json: \
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
flex: out/flex/index.json
out/flex/index.json: \
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
gcc: out/gcc/index.json
out/gcc/index.json: \
	src/core/gcc/Containerfile \
	stage3 \
	binutils \
	busybox \
	musl
	$(call build,core,gcc)

PHONY: gettext
gettext: out/gettext/index.json
out/gettext/index.json: \
	src/core/gettext/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,gettext)

PHONY: go
go: out/go/index.json
out/go/index.json: \
	src/core/go/Containerfile \
	bash \
	binutils \
	busybox \
	gcc \
	musl
	$(call build,core,go)

PHONY: libtool
libtool: out/libtool/index.json
out/libtool/index.json: \
	src/core/libtool/Containerfile \
	binutils \
	busybox \
	gcc \
	m4 \
	make \
	musl
	$(call build,core,libtool)

PHONY: libunwind
libunwind: out/libunwind/index.json
out/libunwind/index.json: \
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
libzstd: out/libzstd/index.json
out/libzstd/index.json: \
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
linux-headers: out/linux-headers/index.json
out/linux-headers/index.json: \
	src/core/linux-headers/Containerfile \
	stage3
	$(call build,core,linux-headers)

PHONY: m4
m4: out/m4/index.json
out/m4/index.json: \
	src/core/m4/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,m4)

PHONY: make
make: out/make/index.json
out/make/index.json: \
	src/core/make/Containerfile \
	stage3
	$(call build,core,make)

PHONY: meson
meson: out/meson/index.json
out/meson/index.json: \
	src/core/meson/Containerfile \
	busybox \
	py-setuptools \
	python \
	zlib
	$(call build,core,meson)

PHONY: musl
musl: out/musl/index.json
out/musl/index.json: \
	src/core/musl/Containerfile \
	stage3
	$(call build,core,musl)

PHONY: musl-fts
musl-fts: out/musl-fts/index.json
out/musl-fts/index.json: \
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
musl-obstack: out/musl-obstack/index.json
out/musl-obstack/index.json: \
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
ninja: out/ninja/index.json
out/ninja/index.json: \
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
openssl: out/openssl/index.json
out/openssl/index.json: \
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
perl: out/perl/index.json
out/perl/index.json: \
	src/core/perl/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,perl)

PHONY: pkgconf
pkgconf: out/pkgconf/index.json
out/pkgconf/index.json: \
	src/core/pkgconf/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,pkgconf)

PHONY: py-setuptools
py-setuptools: out/py-setuptools/index.json
out/py-setuptools/index.json: \
	src/core/py-setuptools/Containerfile \
	busybox \
	python \
	zlib
	$(call build,core,py-setuptools)

PHONY: python
python: out/python/index.json
out/python/index.json: \
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
sed: out/sed/index.json
out/sed/index.json: \
	src/core/sed/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,sed)

PHONY: zlib
zlib: out/zlib/index.json
out/zlib/index.json: \
	src/core/zlib/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,core,zlib)

PHONY: linux-generic
linux-generic: out/linux-generic/index.json
out/linux-generic/index.json: \
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
ca-certificates: out/ca-certificates/index.json
out/ca-certificates/index.json: \
	src/libs/ca-certificates/Containerfile \
	busybox
	$(call build,libs,ca-certificates)

PHONY: libxml2
libxml2: out/libxml2/index.json
out/libxml2/index.json: \
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
cpio: out/cpio/index.json
out/cpio/index.json: \
	src/tools/cpio/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl
	$(call build,tools,cpio)

PHONY: curl
curl: out/curl/index.json
out/curl/index.json: \
	src/tools/curl/Containerfile \
	binutils \
	busybox \
	gcc \
	make \
	musl \
	openssl
	$(call build,tools,curl)

PHONY: gen_initramfs
gen_initramfs: out/gen_initramfs/index.json
out/gen_initramfs/index.json: \
	src/tools/gen_initramfs/Containerfile \
	binutils \
	busybox \
	gcc \
	musl
	$(call build,tools,gen_initramfs)

PHONY: sops
sops: out/sops/index.json
out/sops/index.json: \
	src/tools/sops/Containerfile \
	busybox \
	go \
	ca-certificates
	$(call build,tools,sops)

PHONY: tofu
tofu: out/tofu/index.json
out/tofu/index.json: \
	src/tools/tofu/Containerfile \
	busybox \
	go \
	ca-certificates
	$(call build,tools,tofu)

