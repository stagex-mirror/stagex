
.PHONY: stage0
stage0: out/stage0/index.json
out/stage0/index.json: \
	src/bootstrap/stage0/Containerfile
	$(call build,bootstrap,stage0)

.PHONY: stage1
stage1: out/stage1/index.json
out/stage1/index.json: \
	src/bootstrap/stage1/Containerfile \
	out/stage0/index.json
	$(call build,bootstrap,stage1)

.PHONY: stage2
stage2: out/stage2/index.json
out/stage2/index.json: \
	src/bootstrap/stage2/Containerfile \
	out/stage1/index.json
	$(call build,bootstrap,stage2)

.PHONY: stage3
stage3: out/stage3/index.json
out/stage3/index.json: \
	src/bootstrap/stage3/Containerfile \
	out/stage2/index.json
	$(call build,bootstrap,stage3)

.PHONY: argp-standalone
argp-standalone: out/argp-standalone/index.json
out/argp-standalone/index.json: \
	src/core/argp-standalone/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,core,argp-standalone)

.PHONY: autoconf
autoconf: out/autoconf/index.json
out/autoconf/index.json: \
	src/core/autoconf/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,core,autoconf)

.PHONY: automake
automake: out/automake/index.json
out/automake/index.json: \
	src/core/automake/Containerfile \
	out/autoconf/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,core,automake)

.PHONY: bash
bash: out/bash/index.json
out/bash/index.json: \
	src/core/bash/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,bash)

.PHONY: binutils
binutils: out/binutils/index.json
out/binutils/index.json: \
	src/core/binutils/Containerfile \
	out/stage3/index.json
	$(call build,core,binutils)

.PHONY: bison
bison: out/bison/index.json
out/bison/index.json: \
	src/core/bison/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,core,bison)

.PHONY: busybox
busybox: out/busybox/index.json
out/busybox/index.json: \
	src/core/busybox/Containerfile \
	out/stage3/index.json
	$(call build,core,busybox)

.PHONY: cmake
cmake: out/cmake/index.json
out/cmake/index.json: \
	src/core/cmake/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,core,cmake)

.PHONY: elfutils
elfutils: out/elfutils/index.json
out/elfutils/index.json: \
	src/core/elfutils/Containerfile \
	out/argp-standalone/index.json \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/musl-fts/index.json \
	out/musl-obstack/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,core,elfutils)

.PHONY: flex
flex: out/flex/index.json
out/flex/index.json: \
	src/core/flex/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,core,flex)

.PHONY: gcc
gcc: out/gcc/index.json
out/gcc/index.json: \
	src/core/gcc/Containerfile \
	out/binutils/index.json \
	out/musl/index.json \
	out/stage3/index.json
	$(call build,core,gcc)

.PHONY: gettext
gettext: out/gettext/index.json
out/gettext/index.json: \
	src/core/gettext/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libxml2/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,gettext)

.PHONY: go
go: out/go/index.json
out/go/index.json: \
	src/core/go/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/musl/index.json
	$(call build,core,go)

.PHONY: libtool
libtool: out/libtool/index.json
out/libtool/index.json: \
	src/core/libtool/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,libtool)

.PHONY: libunwind
libunwind: out/libunwind/index.json
out/libunwind/index.json: \
	src/core/libunwind/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,libunwind)

.PHONY: libzstd
libzstd: out/libzstd/index.json
out/libzstd/index.json: \
	src/core/libzstd/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/meson/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,core,libzstd)

.PHONY: linux-headers
linux-headers: out/linux-headers/index.json
out/linux-headers/index.json: \
	src/core/linux-headers/Containerfile \
	out/stage3/index.json
	$(call build,core,linux-headers)

.PHONY: llvm
llvm: out/llvm/index.json
out/llvm/index.json: \
	src/core/llvm/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/gcc/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,core,llvm)

.PHONY: llvm13
llvm13: out/llvm13/index.json
out/llvm13/index.json: \
	src/core/llvm13/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/gcc/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,core,llvm13)

.PHONY: m4
m4: out/m4/index.json
out/m4/index.json: \
	src/core/m4/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,m4)

.PHONY: make
make: out/make/index.json
out/make/index.json: \
	src/core/make/Containerfile \
	out/stage3/index.json
	$(call build,core,make)

.PHONY: meson
meson: out/meson/index.json
out/meson/index.json: \
	src/core/meson/Containerfile \
	out/busybox/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,core,meson)

.PHONY: musl
musl: out/musl/index.json
out/musl/index.json: \
	src/core/musl/Containerfile \
	out/stage3/index.json
	$(call build,core,musl)

.PHONY: musl-fts
musl-fts: out/musl-fts/index.json
out/musl-fts/index.json: \
	src/core/musl-fts/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,core,musl-fts)

.PHONY: musl-obstack
musl-obstack: out/musl-obstack/index.json
out/musl-obstack/index.json: \
	src/core/musl-obstack/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,core,musl-obstack)

.PHONY: ninja
ninja: out/ninja/index.json
out/ninja/index.json: \
	src/core/ninja/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/python/index.json
	$(call build,core,ninja)

.PHONY: openssl
openssl: out/openssl/index.json
out/openssl/index.json: \
	src/core/openssl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,core,openssl)

.PHONY: perl
perl: out/perl/index.json
out/perl/index.json: \
	src/core/perl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,perl)

.PHONY: pkgconf
pkgconf: out/pkgconf/index.json
out/pkgconf/index.json: \
	src/core/pkgconf/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,pkgconf)

.PHONY: py-setuptools
py-setuptools: out/py-setuptools/index.json
out/py-setuptools/index.json: \
	src/core/py-setuptools/Containerfile \
	out/busybox/index.json \
	out/musl/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,core,py-setuptools)

.PHONY: python
python: out/python/index.json
out/python/index.json: \
	src/core/python/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,core,python)

.PHONY: rust
rust: out/rust/index.json
out/rust/index.json: \
	src/core/rust/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/gcc/index.json \
	out/libunwind/index.json \
	out/llvm/index.json \
	out/llvm13/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,core,rust)

.PHONY: sed
sed: out/sed/index.json
out/sed/index.json: \
	src/core/sed/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,sed)

.PHONY: xorriso
xorriso: out/xorriso/index.json
out/xorriso/index.json: \
	src/core/xorriso/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,xorriso)

.PHONY: zlib
zlib: out/zlib/index.json
out/zlib/index.json: \
	src/core/zlib/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,core,zlib)

.PHONY: linux-generic
linux-generic: out/linux-generic/index.json
out/linux-generic/index.json: \
	src/kernel/linux-generic/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/elfutils/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,kernel,linux-generic)

.PHONY: linux-nitro
linux-nitro: out/linux-nitro/index.json
out/linux-nitro/index.json: \
	src/kernel/linux-nitro/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/elfutils/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,kernel,linux-nitro)

.PHONY: ca-certificates
ca-certificates: out/ca-certificates/index.json
out/ca-certificates/index.json: \
	src/libs/ca-certificates/Containerfile
	$(call build,libs,ca-certificates)

.PHONY: libassuan
libassuan: out/libassuan/index.json
out/libassuan/index.json: \
	src/libs/libassuan/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libs,libassuan)

.PHONY: libgcrypt
libgcrypt: out/libgcrypt/index.json
out/libgcrypt/index.json: \
	src/libs/libgcrypt/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libs,libgcrypt)

.PHONY: libgpg-error
libgpg-error: out/libgpg-error/index.json
out/libgpg-error/index.json: \
	src/libs/libgpg-error/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/npth/index.json
	$(call build,libs,libgpg-error)

.PHONY: libksba
libksba: out/libksba/index.json
out/libksba/index.json: \
	src/libs/libksba/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/npth/index.json \
	out/zlib/index.json
	$(call build,libs,libksba)

.PHONY: libxml2
libxml2: out/libxml2/index.json
out/libxml2/index.json: \
	src/libs/libxml2/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,libs,libxml2)

.PHONY: npth
npth: out/npth/index.json
out/npth/index.json: \
	src/libs/npth/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/zlib/index.json
	$(call build,libs,npth)

.PHONY: cpio
cpio: out/cpio/index.json
out/cpio/index.json: \
	src/tools/cpio/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,tools,cpio)

.PHONY: curl
curl: out/curl/index.json
out/curl/index.json: \
	src/tools/curl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,tools,curl)

.PHONY: eif_build
eif_build: out/eif_build/index.json
out/eif_build/index.json: \
	src/tools/eif_build/Containerfile \
	out/busybox/index.json \
	out/libunwind/index.json \
	out/musl/index.json \
	out/rust/index.json
	$(call build,tools,eif_build)

.PHONY: gen_initramfs
gen_initramfs: out/gen_initramfs/index.json
out/gen_initramfs/index.json: \
	src/tools/gen_initramfs/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/musl/index.json
	$(call build,tools,gen_initramfs)

.PHONY: git
git: out/git/index.json
out/git/index.json: \
	src/tools/git/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/zlib/index.json
	$(call build,tools,git)

.PHONY: gpg
gpg: out/gpg/index.json
out/gpg/index.json: \
	src/tools/gpg/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libassuan/index.json \
	out/libgcrypt/index.json \
	out/libgpg-error/index.json \
	out/libksba/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/npth/index.json \
	out/zlib/index.json
	$(call build,tools,gpg)

.PHONY: sops
sops: out/sops/index.json
out/sops/index.json: \
	src/tools/sops/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/go/index.json
	$(call build,tools,sops)

.PHONY: sxctl
sxctl: out/sxctl/index.json
out/sxctl/index.json: \
	src/tools/sxctl/Containerfile \
	out/busybox/index.json \
	out/go/index.json
	$(call build,tools,sxctl)

.PHONY: tofu
tofu: out/tofu/index.json
out/tofu/index.json: \
	src/tools/tofu/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/go/index.json
	$(call build,tools,tofu)

