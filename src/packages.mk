
.PHONY: argp-standalone
argp-standalone: out/argp-standalone/index.json
out/argp-standalone/index.json: \
	packages/argp-standalone/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,argp-standalone)

.PHONY: autoconf
autoconf: out/autoconf/index.json
out/autoconf/index.json: \
	packages/autoconf/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,autoconf)

.PHONY: automake
automake: out/automake/index.json
out/automake/index.json: \
	packages/automake/Containerfile \
	out/autoconf/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,automake)

.PHONY: bash
bash: out/bash/index.json
out/bash/index.json: \
	packages/bash/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,bash)

.PHONY: binutils
binutils: out/binutils/index.json
out/binutils/index.json: \
	packages/binutils/Containerfile \
	out/stage3/index.json
	$(call build,binutils)

.PHONY: bison
bison: out/bison/index.json
out/bison/index.json: \
	packages/bison/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,bison)

.PHONY: busybox
busybox: out/busybox/index.json
out/busybox/index.json: \
	packages/busybox/Containerfile \
	out/stage3/index.json
	$(call build,busybox)

.PHONY: ca-certificates
ca-certificates: out/ca-certificates/index.json
out/ca-certificates/index.json: \
	packages/ca-certificates/Containerfile
	$(call build,ca-certificates)

.PHONY: cmake
cmake: out/cmake/index.json
out/cmake/index.json: \
	packages/cmake/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,cmake)

.PHONY: cpio
cpio: out/cpio/index.json
out/cpio/index.json: \
	packages/cpio/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,cpio)

.PHONY: curl
curl: out/curl/index.json
out/curl/index.json: \
	packages/curl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,curl)

.PHONY: eif_build
eif_build: out/eif_build/index.json
out/eif_build/index.json: \
	packages/eif_build/Containerfile \
	out/busybox/index.json \
	out/libunwind/index.json \
	out/musl/index.json \
	out/rust/index.json
	$(call build,eif_build)

.PHONY: elfutils
elfutils: out/elfutils/index.json
out/elfutils/index.json: \
	packages/elfutils/Containerfile \
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
	$(call build,elfutils)

.PHONY: flex
flex: out/flex/index.json
out/flex/index.json: \
	packages/flex/Containerfile \
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
	$(call build,flex)

.PHONY: gcc
gcc: out/gcc/index.json
out/gcc/index.json: \
	packages/gcc/Containerfile \
	out/binutils/index.json \
	out/musl/index.json \
	out/stage3/index.json
	$(call build,gcc)

.PHONY: gen_initramfs
gen_initramfs: out/gen_initramfs/index.json
out/gen_initramfs/index.json: \
	packages/gen_initramfs/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/musl/index.json
	$(call build,gen_initramfs)

.PHONY: gettext
gettext: out/gettext/index.json
out/gettext/index.json: \
	packages/gettext/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libxml2/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,gettext)

.PHONY: git
git: out/git/index.json
out/git/index.json: \
	packages/git/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/zlib/index.json
	$(call build,git)

.PHONY: go
go: out/go/index.json
out/go/index.json: \
	packages/go/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/musl/index.json
	$(call build,go)

.PHONY: gpg
gpg: out/gpg/index.json
out/gpg/index.json: \
	packages/gpg/Containerfile \
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
	$(call build,gpg)

.PHONY: grub
grub: out/grub/index.json
out/grub/index.json: \
	packages/grub/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/python/index.json
	$(call build,grub)

.PHONY: libassuan
libassuan: out/libassuan/index.json
out/libassuan/index.json: \
	packages/libassuan/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libassuan)

.PHONY: libgcrypt
libgcrypt: out/libgcrypt/index.json
out/libgcrypt/index.json: \
	packages/libgcrypt/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libgcrypt)

.PHONY: libgpg-error
libgpg-error: out/libgpg-error/index.json
out/libgpg-error/index.json: \
	packages/libgpg-error/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/npth/index.json
	$(call build,libgpg-error)

.PHONY: libksba
libksba: out/libksba/index.json
out/libksba/index.json: \
	packages/libksba/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/npth/index.json \
	out/zlib/index.json
	$(call build,libksba)

.PHONY: libtool
libtool: out/libtool/index.json
out/libtool/index.json: \
	packages/libtool/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libtool)

.PHONY: libunwind
libunwind: out/libunwind/index.json
out/libunwind/index.json: \
	packages/libunwind/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libunwind)

.PHONY: libxml2
libxml2: out/libxml2/index.json
out/libxml2/index.json: \
	packages/libxml2/Containerfile \
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
	$(call build,libxml2)

.PHONY: libzstd
libzstd: out/libzstd/index.json
out/libzstd/index.json: \
	packages/libzstd/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/meson/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,libzstd)

.PHONY: linux-generic
linux-generic: out/linux-generic/index.json
out/linux-generic/index.json: \
	packages/linux-generic/Containerfile \
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
	$(call build,linux-generic)

.PHONY: linux-headers
linux-headers: out/linux-headers/index.json
out/linux-headers/index.json: \
	packages/linux-headers/Containerfile \
	out/stage3/index.json
	$(call build,linux-headers)

.PHONY: linux-nitro
linux-nitro: out/linux-nitro/index.json
out/linux-nitro/index.json: \
	packages/linux-nitro/Containerfile \
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
	$(call build,linux-nitro)

.PHONY: llvm
llvm: out/llvm/index.json
out/llvm/index.json: \
	packages/llvm/Containerfile \
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
	$(call build,llvm)

.PHONY: llvm13
llvm13: out/llvm13/index.json
out/llvm13/index.json: \
	packages/llvm13/Containerfile \
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
	$(call build,llvm13)

.PHONY: m4
m4: out/m4/index.json
out/m4/index.json: \
	packages/m4/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,m4)

.PHONY: make
make: out/make/index.json
out/make/index.json: \
	packages/make/Containerfile \
	out/stage3/index.json
	$(call build,make)

.PHONY: meson
meson: out/meson/index.json
out/meson/index.json: \
	packages/meson/Containerfile \
	out/busybox/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,meson)

.PHONY: musl
musl: out/musl/index.json
out/musl/index.json: \
	packages/musl/Containerfile \
	out/stage3/index.json
	$(call build,musl)

.PHONY: musl-fts
musl-fts: out/musl-fts/index.json
out/musl-fts/index.json: \
	packages/musl-fts/Containerfile \
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
	$(call build,musl-fts)

.PHONY: musl-obstack
musl-obstack: out/musl-obstack/index.json
out/musl-obstack/index.json: \
	packages/musl-obstack/Containerfile \
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
	$(call build,musl-obstack)

.PHONY: ninja
ninja: out/ninja/index.json
out/ninja/index.json: \
	packages/ninja/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/python/index.json
	$(call build,ninja)

.PHONY: npth
npth: out/npth/index.json
out/npth/index.json: \
	packages/npth/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/zlib/index.json
	$(call build,npth)

.PHONY: openssl
openssl: out/openssl/index.json
out/openssl/index.json: \
	packages/openssl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,openssl)

.PHONY: pcsc-lite
pcsc-lite: out/pcsc-lite/index.json
out/pcsc-lite/index.json: \
	packages/pcsc-lite/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,pcsc-lite)

.PHONY: perl
perl: out/perl/index.json
out/perl/index.json: \
	packages/perl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,perl)

.PHONY: pkgconf
pkgconf: out/pkgconf/index.json
out/pkgconf/index.json: \
	packages/pkgconf/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,pkgconf)

.PHONY: py-setuptools
py-setuptools: out/py-setuptools/index.json
out/py-setuptools/index.json: \
	packages/py-setuptools/Containerfile \
	out/busybox/index.json \
	out/musl/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-setuptools)

.PHONY: python
python: out/python/index.json
out/python/index.json: \
	packages/python/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,python)

.PHONY: rust
rust: out/rust/index.json
out/rust/index.json: \
	packages/rust/Containerfile \
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
	$(call build,rust)

.PHONY: sed
sed: out/sed/index.json
out/sed/index.json: \
	packages/sed/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,sed)

.PHONY: sops
sops: out/sops/index.json
out/sops/index.json: \
	packages/sops/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/go/index.json
	$(call build,sops)

.PHONY: stage0
stage0: out/stage0/index.json
out/stage0/index.json: \
	packages/stage0/Containerfile
	$(call build,stage0)

.PHONY: stage1
stage1: out/stage1/index.json
out/stage1/index.json: \
	packages/stage1/Containerfile \
	out/stage0/index.json
	$(call build,stage1)

.PHONY: stage2
stage2: out/stage2/index.json
out/stage2/index.json: \
	packages/stage2/Containerfile \
	out/stage1/index.json
	$(call build,stage2)

.PHONY: stage3
stage3: out/stage3/index.json
out/stage3/index.json: \
	packages/stage3/Containerfile \
	out/stage2/index.json
	$(call build,stage3)

.PHONY: sxctl
sxctl: out/sxctl/index.json
out/sxctl/index.json: \
	packages/sxctl/Containerfile \
	out/busybox/index.json \
	out/go/index.json
	$(call build,sxctl)

.PHONY: tofu
tofu: out/tofu/index.json
out/tofu/index.json: \
	packages/tofu/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/go/index.json
	$(call build,tofu)

.PHONY: xorriso
xorriso: out/xorriso/index.json
out/xorriso/index.json: \
	packages/xorriso/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,xorriso)

.PHONY: zlib
zlib: out/zlib/index.json
out/zlib/index.json: \
	packages/zlib/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,zlib)

