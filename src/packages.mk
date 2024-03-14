
.PHONY: argp-standalone
argp-standalone: out/argp-standalone/index.json
out/argp-standalone/index.json: \
	packages/argp-standalone/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,bash)

.PHONY: bc
bc: out/bc/index.json
out/bc/index.json: \
	packages/bc/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/coreutils/index.json \
	out/ed/index.json \
	out/filesystem/index.json \
	out/findutils/index.json \
	out/flex/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/grep/index.json \
	out/gzip/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/sed/index.json \
	out/tar/index.json \
	out/texinfo/index.json
	$(call build,bc)

.PHONY: binutils
binutils: out/binutils/index.json
out/binutils/index.json: \
	packages/binutils/Containerfile \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/stage3/index.json
	$(call build,busybox)

.PHONY: bzip2
bzip2: out/bzip2/index.json
out/bzip2/index.json: \
	packages/bzip2/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,bzip2)

.PHONY: ca-certificates
ca-certificates: out/ca-certificates/index.json
out/ca-certificates/index.json: \
	packages/ca-certificates/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json
	$(call build,ca-certificates)

.PHONY: clang
clang: out/clang/index.json
out/clang/index.json: \
	packages/clang/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/llvm/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,clang)

.PHONY: cmake
cmake: out/cmake/index.json
out/cmake/index.json: \
	packages/cmake/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,cmake)

.PHONY: coreutils
coreutils: out/coreutils/index.json
out/coreutils/index.json: \
	packages/coreutils/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,coreutils)

.PHONY: cpio
cpio: out/cpio/index.json
out/cpio/index.json: \
	packages/cpio/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,curl)

.PHONY: diffutils
diffutils: out/diffutils/index.json
out/diffutils/index.json: \
	packages/diffutils/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,diffutils)

.PHONY: dosfstools
dosfstools: out/dosfstools/index.json
out/dosfstools/index.json: \
	packages/dosfstools/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,dosfstools)

.PHONY: ed
ed: out/ed/index.json
out/ed/index.json: \
	packages/ed/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/lzip/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/tar/index.json
	$(call build,ed)

.PHONY: eif_build
eif_build: out/eif_build/index.json
out/eif_build/index.json: \
	packages/eif_build/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/git/index.json \
	out/libunwind/index.json \
	out/llvm/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/pkgconf/index.json \
	out/rust/index.json \
	out/zlib/index.json
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
	out/filesystem/index.json \
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

.PHONY: eudev
eudev: out/eudev/index.json
out/eudev/index.json: \
	packages/eudev/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gperf/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,eudev)

.PHONY: file
file: out/file/index.json
out/file/index.json: \
	packages/file/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,file)

.PHONY: filesystem
filesystem: out/filesystem/index.json
out/filesystem/index.json: \
	packages/filesystem/Containerfile \
	out/stage3/index.json
	$(call build,filesystem)

.PHONY: findutils
findutils: out/findutils/index.json
out/findutils/index.json: \
	packages/findutils/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,findutils)

.PHONY: flex
flex: out/flex/index.json
out/flex/index.json: \
	packages/flex/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,flex)

.PHONY: gawk
gawk: out/gawk/index.json
out/gawk/index.json: \
	packages/gawk/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,gawk)

.PHONY: gcc
gcc: out/gcc/index.json
out/gcc/index.json: \
	packages/gcc/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/stage3/index.json
	$(call build,gcc)

.PHONY: gen_initramfs
gen_initramfs: out/gen_initramfs/index.json
out/gen_initramfs/index.json: \
	packages/gen_initramfs/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/musl/index.json
	$(call build,gen_initramfs)

.PHONY: gettext
gettext: out/gettext/index.json
out/gettext/index.json: \
	packages/gettext/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/zlib/index.json
	$(call build,git)

.PHONY: gmp
gmp: out/gmp/index.json
out/gmp/index.json: \
	packages/gmp/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,gmp)

.PHONY: go
go: out/go/index.json
out/go/index.json: \
	packages/go/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/musl/index.json
	$(call build,go)

.PHONY: gperf
gperf: out/gperf/index.json
out/gperf/index.json: \
	packages/gperf/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,gperf)

.PHONY: gpg
gpg: out/gpg/index.json
out/gpg/index.json: \
	packages/gpg/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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

.PHONY: grep
grep: out/grep/index.json
out/grep/index.json: \
	packages/grep/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,grep)

.PHONY: grub
grub: out/grub/index.json
out/grub/index.json: \
	packages/grub/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/python/index.json
	$(call build,grub)

.PHONY: gzip
gzip: out/gzip/index.json
out/gzip/index.json: \
	packages/gzip/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,gzip)

.PHONY: iputils
iputils: out/iputils/index.json
out/iputils/index.json: \
	packages/iputils/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libcap/index.json \
	out/libxslt/index.json \
	out/linux-headers/index.json \
	out/meson/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,iputils)

.PHONY: keyfork
keyfork: out/keyfork/index.json
out/keyfork/index.json: \
	packages/keyfork/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/clang/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gmp/index.json \
	out/libunwind/index.json \
	out/linux-headers/index.json \
	out/llvm/index.json \
	out/musl/index.json \
	out/nettle/index.json \
	out/openssl/index.json \
	out/pcsc-lite/index.json \
	out/pkgconf/index.json \
	out/rust/index.json \
	out/zlib/index.json
	$(call build,keyfork)

.PHONY: libassuan
libassuan: out/libassuan/index.json
out/libassuan/index.json: \
	packages/libassuan/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libassuan)

.PHONY: libcap
libcap: out/libcap/index.json
out/libcap/index.json: \
	packages/libcap/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,libcap)

.PHONY: libgcrypt
libgcrypt: out/libgcrypt/index.json
out/libgcrypt/index.json: \
	packages/libgcrypt/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libgpg-error/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/npth/index.json \
	out/zlib/index.json
	$(call build,libksba)

.PHONY: libqrencode
libqrencode: out/libqrencode/index.json
out/libqrencode/index.json: \
	packages/libqrencode/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libqrencode)

.PHONY: libtool
libtool: out/libtool/index.json
out/libtool/index.json: \
	packages/libtool/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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

.PHONY: libxslt
libxslt: out/libxslt/index.json
out/libxslt/index.json: \
	packages/libxslt/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/libxml2/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,libxslt)

.PHONY: libzstd
libzstd: out/libzstd/index.json
out/libzstd/index.json: \
	packages/libzstd/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/meson/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,libzstd)

.PHONY: linux-airgap
linux-airgap: out/linux-airgap/index.json
out/linux-airgap/index.json: \
	packages/linux-airgap/Containerfile \
	out/bash/index.json \
	out/bc/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/coreutils/index.json \
	out/diffutils/index.json \
	out/elfutils/index.json \
	out/filesystem/index.json \
	out/findutils/index.json \
	out/flex/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/grep/index.json \
	out/gzip/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/sed/index.json \
	out/tar/index.json \
	out/xz/index.json \
	out/zlib/index.json
	$(call build,linux-airgap)

.PHONY: linux-generic
linux-generic: out/linux-generic/index.json
out/linux-generic/index.json: \
	packages/linux-generic/Containerfile \
	out/bash/index.json \
	out/bc/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/coreutils/index.json \
	out/diffutils/index.json \
	out/elfutils/index.json \
	out/filesystem/index.json \
	out/findutils/index.json \
	out/flex/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/grep/index.json \
	out/gzip/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/sed/index.json \
	out/tar/index.json \
	out/xz/index.json \
	out/zlib/index.json
	$(call build,linux-generic)

.PHONY: linux-headers
linux-headers: out/linux-headers/index.json
out/linux-headers/index.json: \
	packages/linux-headers/Containerfile \
	out/filesystem/index.json \
	out/stage3/index.json
	$(call build,linux-headers)

.PHONY: linux-nitro
linux-nitro: out/linux-nitro/index.json
out/linux-nitro/index.json: \
	packages/linux-nitro/Containerfile \
	out/bash/index.json \
	out/bc/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/coreutils/index.json \
	out/diffutils/index.json \
	out/elfutils/index.json \
	out/filesystem/index.json \
	out/findutils/index.json \
	out/flex/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/grep/index.json \
	out/gzip/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/sed/index.json \
	out/tar/index.json \
	out/xz/index.json \
	out/zlib/index.json
	$(call build,linux-nitro)

.PHONY: lld
lld: out/lld/index.json
out/lld/index.json: \
	packages/lld/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/llvm/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,lld)

.PHONY: llvm
llvm: out/llvm/index.json
out/llvm/index.json: \
	packages/llvm/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,llvm13)

.PHONY: lzip
lzip: out/lzip/index.json
out/lzip/index.json: \
	packages/lzip/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,lzip)

.PHONY: m4
m4: out/m4/index.json
out/m4/index.json: \
	packages/m4/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,m4)

.PHONY: make
make: out/make/index.json
out/make/index.json: \
	packages/make/Containerfile \
	out/filesystem/index.json \
	out/stage3/index.json
	$(call build,make)

.PHONY: meson
meson: out/meson/index.json
out/meson/index.json: \
	packages/meson/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,meson)

.PHONY: mtools
mtools: out/mtools/index.json
out/mtools/index.json: \
	packages/mtools/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,mtools)

.PHONY: musl
musl: out/musl/index.json
out/musl/index.json: \
	packages/musl/Containerfile \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,musl-obstack)

.PHONY: nettle
nettle: out/nettle/index.json
out/nettle/index.json: \
	packages/nettle/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gmp/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,nettle)

.PHONY: ninja
ninja: out/ninja/index.json
out/ninja/index.json: \
	packages/ninja/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/eudev/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,pcsc-lite)

.PHONY: perl
perl: out/perl/index.json
out/perl/index.json: \
	packages/perl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,pkgconf)

.PHONY: py-setuptools
py-setuptools: out/py-setuptools/index.json
out/py-setuptools/index.json: \
	packages/py-setuptools/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
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
	out/bzip2/index.json \
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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
	out/filesystem/index.json \
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

.PHONY: strace
strace: out/strace/index.json
out/strace/index.json: \
	packages/strace/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,strace)

.PHONY: sxctl
sxctl: out/sxctl/index.json
out/sxctl/index.json: \
	packages/sxctl/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,sxctl)

.PHONY: syslinux
syslinux: out/syslinux/index.json
out/syslinux/index.json: \
	packages/syslinux/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/util-linux/index.json
	$(call build,syslinux)

.PHONY: tar
tar: out/tar/index.json
out/tar/index.json: \
	packages/tar/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,tar)

.PHONY: texinfo
texinfo: out/texinfo/index.json
out/texinfo/index.json: \
	packages/texinfo/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/coreutils/index.json \
	out/diffutils/index.json \
	out/filesystem/index.json \
	out/findutils/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/grep/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/sed/index.json \
	out/tar/index.json \
	out/xz/index.json
	$(call build,texinfo)

.PHONY: tofu
tofu: out/tofu/index.json
out/tofu/index.json: \
	packages/tofu/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,tofu)

.PHONY: util-linux
util-linux: out/util-linux/index.json
out/util-linux/index.json: \
	packages/util-linux/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,util-linux)

.PHONY: xorriso
xorriso: out/xorriso/index.json
out/xorriso/index.json: \
	packages/xorriso/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,xorriso)

.PHONY: xz
xz: out/xz/index.json
out/xz/index.json: \
	packages/xz/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,xz)

.PHONY: zig
zig: out/zig/index.json
out/zig/index.json: \
	packages/zig/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/clang/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libzstd/index.json \
	out/lld/index.json \
	out/llvm/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,zig)

.PHONY: zlib
zlib: out/zlib/index.json
out/zlib/index.json: \
	packages/zlib/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,zlib)

