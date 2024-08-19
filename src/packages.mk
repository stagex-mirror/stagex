
.PHONY: abseil-cpp
abseil-cpp: out/abseil-cpp/index.json
out/abseil-cpp/index.json: \
	packages/abseil-cpp/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,abseil-cpp)

.PHONY: acl
acl: out/acl/index.json
out/acl/index.json: \
	packages/acl/Containerfile \
	out/attr/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,acl)

.PHONY: alsa-lib
alsa-lib: out/alsa-lib/index.json
out/alsa-lib/index.json: \
	packages/alsa-lib/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,alsa-lib)

.PHONY: apr
apr: out/apr/index.json
out/apr/index.json: \
	packages/apr/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/util-linux/index.json
	$(call build,apr)

.PHONY: apr-util
apr-util: out/apr-util/index.json
out/apr-util/index.json: \
	packages/apr-util/Containerfile \
	out/apr/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/expat/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gdbm/index.json \
	out/libtool/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openldap/index.json \
	out/openssl/index.json \
	out/postgresql/index.json \
	out/sqlite3/index.json \
	out/util-linux/index.json
	$(call build,apr-util)

.PHONY: argon2
argon2: out/argon2/index.json
out/argon2/index.json: \
	packages/argon2/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,argon2)

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

.PHONY: aspell
aspell: out/aspell/index.json
out/aspell/index.json: \
	packages/aspell/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,aspell)

.PHONY: attr
attr: out/attr/index.json
out/attr/index.json: \
	packages/attr/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,attr)

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

.PHONY: autoconf-archive
autoconf-archive: out/autoconf-archive/index.json
out/autoconf-archive/index.json: \
	packages/autoconf-archive/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,autoconf-archive)

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

.PHONY: aws-cli
aws-cli: out/aws-cli/index.json
out/aws-cli/index.json: \
	packages/aws-cli/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/libunwind/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-awscrt/index.json \
	out/py-botocore/index.json \
	out/py-certifi/index.json \
	out/py-cffi/index.json \
	out/py-colorama/index.json \
	out/py-cryptography/index.json \
	out/py-dateutil/index.json \
	out/py-distro/index.json \
	out/py-docutils/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-jmespath/index.json \
	out/py-prompt_toolkit/index.json \
	out/py-ruamel.yaml/index.json \
	out/py-six/index.json \
	out/py-urllib3/index.json \
	out/py-wcwidth/index.json \
	out/python/index.json \
	out/sqlite3/index.json \
	out/zlib/index.json
	$(call build,aws-cli)

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

.PHONY: brotli
brotli: out/brotli/index.json
out/brotli/index.json: \
	packages/brotli/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/samurai/index.json
	$(call build,brotli)

.PHONY: buf
buf: out/buf/index.json
out/buf/index.json: \
	packages/buf/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,buf)

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
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json
	$(call build,ca-certificates)

.PHONY: ccid
ccid: out/ccid/index.json
out/ccid/index.json: \
	packages/ccid/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/libusb/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/pcsc-lite/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,ccid)

.PHONY: clang
clang: out/clang/index.json
out/clang/index.json: \
	packages/clang/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/git/index.json \
	out/libxml2/index.json \
	out/linux-headers/index.json \
	out/llvm/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/samurai/index.json \
	out/zlib/index.json
	$(call build,clang)

.PHONY: clang16
clang16: out/clang16/index.json
out/clang16/index.json: \
	packages/clang16/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/llvm16/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,clang16)

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
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json
	$(call build,curl)

.PHONY: cython
cython: out/cython/index.json
out/cython/index.json: \
	packages/cython/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-cffi/index.json \
	out/py-dateutil/index.json \
	out/py-distro/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-urllib3/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,cython)

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

.PHONY: docbook-xml
docbook-xml: out/docbook-xml/index.json
out/docbook-xml/index.json: \
	packages/docbook-xml/Containerfile \
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
	$(call build,docbook-xml)

.PHONY: docbook-xsl
docbook-xsl: out/docbook-xsl/index.json
out/docbook-xsl/index.json: \
	packages/docbook-xsl/Containerfile \
	out/busybox/index.json \
	out/docbook-xml/index.json \
	out/filesystem/index.json \
	out/libxml2/index.json \
	out/musl/index.json \
	out/zlib/index.json
	$(call build,docbook-xsl)

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

.PHONY: doxygen
doxygen: out/doxygen/index.json
out/doxygen/index.json: \
	packages/doxygen/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/coreutils/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/libxml2/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/samurai/index.json
	$(call build,doxygen)

.PHONY: dtc
dtc: out/dtc/index.json
out/dtc/index.json: \
	packages/dtc/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/coreutils/index.json \
	out/filesystem/index.json \
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
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,dtc)

.PHONY: e2fsprogs
e2fsprogs: out/e2fsprogs/index.json
out/e2fsprogs/index.json: \
	packages/e2fsprogs/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/pkgconf/index.json \
	out/util-linux/index.json
	$(call build,e2fsprogs)

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
	out/llvm16/index.json \
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

.PHONY: expat
expat: out/expat/index.json
out/expat/index.json: \
	packages/expat/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,expat)

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

.PHONY: flashtools
flashtools: out/flashtools/index.json
out/flashtools/index.json: \
	packages/flashtools/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,flashtools)

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

.PHONY: fmt
fmt: out/fmt/index.json
out/fmt/index.json: \
	packages/fmt/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/doxygen/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/postgresql/index.json \
	out/python/index.json \
	out/samurai/index.json
	$(call build,fmt)

.PHONY: freetds
freetds: out/freetds/index.json
out/freetds/index.json: \
	packages/freetds/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/readline/index.json \
	out/unixodbc/index.json
	$(call build,freetds)

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

.PHONY: gdbm
gdbm: out/gdbm/index.json
out/gdbm/index.json: \
	packages/gdbm/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,gdbm)

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
	out/curl/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/zlib/index.json
	$(call build,git)

.PHONY: glib
glib: out/glib/index.json
out/glib/index.json: \
	packages/glib/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/bzip2/index.json \
	out/cmake/index.json \
	out/expat/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libffi/index.json \
	out/libxml2/index.json \
	out/libxslt/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/meson/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/ninja/index.json \
	out/pcre2/index.json \
	out/pkgconf/index.json \
	out/py-packaging/index.json \
	out/python/index.json \
	out/rhash/index.json \
	out/util-linux/index.json \
	out/xz/index.json \
	out/zlib/index.json
	$(call build,glib)

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

.PHONY: go-md2man
go-md2man: out/go-md2man/index.json
out/go-md2man/index.json: \
	packages/go-md2man/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,go-md2man)

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

.PHONY: groff
groff: out/groff/index.json
out/groff/index.json: \
	packages/groff/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,groff)

.PHONY: grpcurl
grpcurl: out/grpcurl/index.json
out/grpcurl/index.json: \
	packages/grpcurl/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,grpcurl)

.PHONY: grub
grub: out/grub/index.json
out/grub/index.json: \
	packages/grub/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/xz/index.json
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

.PHONY: helm
helm: out/helm/index.json
out/helm/index.json: \
	packages/helm/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,helm)

.PHONY: hunspell
hunspell: out/hunspell/index.json
out/hunspell/index.json: \
	packages/hunspell/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,hunspell)

.PHONY: icu
icu: out/icu/index.json
out/icu/index.json: \
	packages/icu/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,icu)

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

.PHONY: jq
jq: out/jq/index.json
out/jq/index.json: \
	packages/jq/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,jq)

.PHONY: json-c
json-c: out/json-c/index.json
out/json-c/index.json: \
	packages/json-c/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,json-c)

.PHONY: k9s
k9s: out/k9s/index.json
out/k9s/index.json: \
	packages/k9s/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,k9s)

.PHONY: keyfork
keyfork: out/keyfork/index.json
out/keyfork/index.json: \
	packages/keyfork/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/clang16/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gmp/index.json \
	out/libunwind/index.json \
	out/linux-headers/index.json \
	out/llvm16/index.json \
	out/musl/index.json \
	out/nettle/index.json \
	out/openssl/index.json \
	out/pcsc-lite/index.json \
	out/pkgconf/index.json \
	out/rust/index.json \
	out/zlib/index.json
	$(call build,keyfork)

.PHONY: krb5
krb5: out/krb5/index.json
out/krb5/index.json: \
	packages/krb5/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/curl/index.json \
	out/e2fsprogs/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/groff/index.json \
	out/libevent/index.json \
	out/libtool/index.json \
	out/libverto/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openldap/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/util-linux/index.json
	$(call build,krb5)

.PHONY: ksops-dry-run
ksops-dry-run: out/ksops-dry-run/index.json
out/ksops-dry-run/index.json: \
	packages/ksops-dry-run/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,ksops-dry-run)

.PHONY: kubeconform
kubeconform: out/kubeconform/index.json
out/kubeconform/index.json: \
	packages/kubeconform/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,kubeconform)

.PHONY: kubectl
kubectl: out/kubectl/index.json
out/kubectl/index.json: \
	packages/kubectl/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,kubectl)

.PHONY: kustomize
kustomize: out/kustomize/index.json
out/kustomize/index.json: \
	packages/kustomize/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,kustomize)

.PHONY: kustomize-sops
kustomize-sops: out/kustomize-sops/index.json
out/kustomize-sops/index.json: \
	packages/kustomize-sops/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,kustomize-sops)

.PHONY: libaio
libaio: out/libaio/index.json
out/libaio/index.json: \
	packages/libaio/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libaio)

.PHONY: libarchive
libarchive: out/libarchive/index.json
out/libarchive/index.json: \
	packages/libarchive/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libarchive)

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

.PHONY: libcap-ng
libcap-ng: out/libcap-ng/index.json
out/libcap-ng/index.json: \
	packages/libcap-ng/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libcap-ng)

.PHONY: libedit
libedit: out/libedit/index.json
out/libedit/index.json: \
	packages/libedit/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/perl/index.json
	$(call build,libedit)

.PHONY: libevent
libevent: out/libevent/index.json
out/libevent/index.json: \
	packages/libevent/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,libevent)

.PHONY: libffi
libffi: out/libffi/index.json
out/libffi/index.json: \
	packages/libffi/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libffi)

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

.PHONY: libical
libical: out/libical/index.json
out/libical/index.json: \
	packages/libical/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/icu/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/samurai/index.json
	$(call build,libical)

.PHONY: libiconv
libiconv: out/libiconv/index.json
out/libiconv/index.json: \
	packages/libiconv/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,libiconv)

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

.PHONY: libseccomp
libseccomp: out/libseccomp/index.json
out/libseccomp/index.json: \
	packages/libseccomp/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cython/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gperf/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,libseccomp)

.PHONY: libsodium
libsodium: out/libsodium/index.json
out/libsodium/index.json: \
	packages/libsodium/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libsodium)

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

.PHONY: libusb
libusb: out/libusb/index.json
out/libusb/index.json: \
	packages/libusb/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,libusb)

.PHONY: libverto
libverto: out/libverto/index.json
out/libverto/index.json: \
	packages/libverto/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/curl/index.json \
	out/e2fsprogs/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/groff/index.json \
	out/libedit/index.json \
	out/libevent/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openldap/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/util-linux/index.json
	$(call build,libverto)

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

.PHONY: linux-pam
linux-pam: out/linux-pam/index.json
out/linux-pam/index.json: \
	packages/linux-pam/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/utmps/index.json
	$(call build,linux-pam)

.PHONY: lld
lld: out/lld/index.json
out/lld/index.json: \
	packages/lld/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/llvm16/index.json \
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
	out/linux-headers/index.json \
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

.PHONY: llvm16
llvm16: out/llvm16/index.json
out/llvm16/index.json: \
	packages/llvm16/Containerfile \
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
	$(call build,llvm16)

.PHONY: lmdb
lmdb: out/lmdb/index.json
out/lmdb/index.json: \
	packages/lmdb/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,lmdb)

.PHONY: lua
lua: out/lua/index.json
out/lua/index.json: \
	packages/lua/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/perl/index.json \
	out/readline/index.json \
	out/zlib/index.json
	$(call build,lua)

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

.PHONY: lzo
lzo: out/lzo/index.json
out/lzo/index.json: \
	packages/lzo/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,lzo)

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

.PHONY: mdbook
mdbook: out/mdbook/index.json
out/mdbook/index.json: \
	packages/mdbook/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libunwind/index.json \
	out/llvm16/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/rust/index.json \
	out/zlib/index.json
	$(call build,mdbook)

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

.PHONY: mockgen
mockgen: out/mockgen/index.json
out/mockgen/index.json: \
	packages/mockgen/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,mockgen)

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

.PHONY: ncurses
ncurses: out/ncurses/index.json
out/ncurses/index.json: \
	packages/ncurses/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,ncurses)

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

.PHONY: numactl
numactl: out/numactl/index.json
out/numactl/index.json: \
	packages/numactl/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gperf/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,numactl)

.PHONY: nuspell
nuspell: out/nuspell/index.json
out/nuspell/index.json: \
	packages/nuspell/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/icu/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/samurai/index.json
	$(call build,nuspell)

.PHONY: ocaml
ocaml: out/ocaml/index.json
out/ocaml/index.json: \
	packages/ocaml/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libzstd/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,ocaml)

.PHONY: ocismack
ocismack: out/ocismack/index.json
out/ocismack/index.json: \
	packages/ocismack/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libunwind/index.json \
	out/llvm16/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/rust/index.json \
	out/zlib/index.json
	$(call build,ocismack)

.PHONY: openldap
openldap: out/openldap/index.json
out/openldap/index.json: \
	packages/openldap/Containerfile \
	out/argon2/index.json \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/groff/index.json \
	out/libedit/index.json \
	out/libevent/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/unixodbc/index.json
	$(call build,openldap)

.PHONY: openpgp-card-tools
openpgp-card-tools: out/openpgp-card-tools/index.json
out/openpgp-card-tools/index.json: \
	packages/openpgp-card-tools/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/clang16/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gmp/index.json \
	out/libunwind/index.json \
	out/linux-headers/index.json \
	out/llvm16/index.json \
	out/musl/index.json \
	out/nettle/index.json \
	out/openssl/index.json \
	out/pcsc-lite/index.json \
	out/pkgconf/index.json \
	out/rust/index.json \
	out/zlib/index.json
	$(call build,openpgp-card-tools)

.PHONY: opensc
opensc: out/opensc/index.json
out/opensc/index.json: \
	packages/opensc/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/openssl/index.json \
	out/pcsc-lite/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/readline/index.json \
	out/util-linux/index.json \
	out/zlib/index.json
	$(call build,opensc)

.PHONY: openssh
openssh: out/openssh/index.json
out/openssh/index.json: \
	packages/openssh/Containerfile \
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
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,openssh)

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

.PHONY: pcre2
pcre2: out/pcre2/index.json
out/pcre2/index.json: \
	packages/pcre2/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/bzip2/index.json \
	out/filesystem/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/libedit/index.json \
	out/libtool/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/perl/index.json \
	out/readline/index.json \
	out/zlib/index.json
	$(call build,pcre2)

.PHONY: pcsc-lite
pcsc-lite: out/pcsc-lite/index.json
out/pcsc-lite/index.json: \
	packages/pcsc-lite/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/libusb/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,pcsc-lite)

.PHONY: pcsc-tools
pcsc-tools: out/pcsc-tools/index.json
out/pcsc-tools/index.json: \
	packages/pcsc-tools/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/pcsc-lite/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,pcsc-tools)

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

.PHONY: perl-dbi
perl-dbi: out/perl-dbi/index.json
out/perl-dbi/index.json: \
	packages/perl-dbi/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,perl-dbi)

.PHONY: perl-module-build
perl-module-build: out/perl-module-build/index.json
out/perl-module-build/index.json: \
	packages/perl-module-build/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,perl-module-build)

.PHONY: perl-pod-parser
perl-pod-parser: out/perl-pod-parser/index.json
out/perl-pod-parser/index.json: \
	packages/perl-pod-parser/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,perl-pod-parser)

.PHONY: perl-yaml-syck
perl-yaml-syck: out/perl-yaml-syck/index.json
out/perl-yaml-syck/index.json: \
	packages/perl-yaml-syck/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json
	$(call build,perl-yaml-syck)

.PHONY: php
php: out/php/index.json
out/php/index.json: \
	packages/php/Containerfile \
	out/acl/index.json \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/bc/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/bzip2/index.json \
	out/clang/index.json \
	out/curl/index.json \
	out/expat/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gdbm/index.json \
	out/gettext/index.json \
	out/gmp/index.json \
	out/icu/index.json \
	out/libedit/index.json \
	out/libunwind/index.json \
	out/libxml2/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/lld/index.json \
	out/llvm/index.json \
	out/lmdb/index.json \
	out/lzip/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/pcre2/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/re2c/index.json \
	out/sqlite3/index.json \
	out/zlib/index.json
	$(call build,php)

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

.PHONY: po4a
po4a: out/po4a/index.json
out/po4a/index.json: \
	packages/po4a/Containerfile \
	out/autoconf/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/diffutils/index.json \
	out/docbook-xml/index.json \
	out/docbook-xsl/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libxml2/index.json \
	out/libxslt/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/perl-module-build/index.json \
	out/perl-pod-parser/index.json \
	out/pkgconf/index.json \
	out/zlib/index.json
	$(call build,po4a)

.PHONY: postgresql
postgresql: out/postgresql/index.json
out/postgresql/index.json: \
	packages/postgresql/Containerfile \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/clang/index.json \
	out/e2fsprogs/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/icu/index.json \
	out/libxml2/index.json \
	out/linux-headers/index.json \
	out/llvm/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/python/index.json \
	out/readline/index.json \
	out/tcl/index.json \
	out/util-linux/index.json \
	out/zlib/index.json
	$(call build,postgresql)

.PHONY: protobuf
protobuf: out/protobuf/index.json
out/protobuf/index.json: \
	packages/protobuf/Containerfile \
	out/abseil-cpp/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/musl/index.json \
	out/ninja/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,protobuf)

.PHONY: protoc-gen-go
protoc-gen-go: out/protoc-gen-go/index.json
out/protoc-gen-go/index.json: \
	packages/protoc-gen-go/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,protoc-gen-go)

.PHONY: protoc-gen-go-grpc
protoc-gen-go-grpc: out/protoc-gen-go-grpc/index.json
out/protoc-gen-go-grpc/index.json: \
	packages/protoc-gen-go-grpc/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,protoc-gen-go-grpc)

.PHONY: protoc-gen-grpc-gateway
protoc-gen-grpc-gateway: out/protoc-gen-grpc-gateway/index.json
out/protoc-gen-grpc-gateway/index.json: \
	packages/protoc-gen-grpc-gateway/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,protoc-gen-grpc-gateway)

.PHONY: protoc-gen-openapiv2
protoc-gen-openapiv2: out/protoc-gen-openapiv2/index.json
out/protoc-gen-openapiv2/index.json: \
	packages/protoc-gen-openapiv2/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,protoc-gen-openapiv2)

.PHONY: protoc-go-inject-tag
protoc-go-inject-tag: out/protoc-go-inject-tag/index.json
out/protoc-go-inject-tag/index.json: \
	packages/protoc-go-inject-tag/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,protoc-go-inject-tag)

.PHONY: py-alabaster
py-alabaster: out/py-alabaster/index.json
out/py-alabaster/index.json: \
	packages/py-alabaster/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-alabaster)

.PHONY: py-awscrt
py-awscrt: out/py-awscrt/index.json
out/py-awscrt/index.json: \
	packages/py-awscrt/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-awscrt)

.PHONY: py-babel
py-babel: out/py-babel/index.json
out/py-babel/index.json: \
	packages/py-babel/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-babel)

.PHONY: py-botocore
py-botocore: out/py-botocore/index.json
out/py-botocore/index.json: \
	packages/py-botocore/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-botocore)

.PHONY: py-build
py-build: out/py-build/index.json
out/py-build/index.json: \
	packages/py-build/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-build)

.PHONY: py-certifi
py-certifi: out/py-certifi/index.json
out/py-certifi/index.json: \
	packages/py-certifi/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-certifi)

.PHONY: py-cffi
py-cffi: out/py-cffi/index.json
out/py-cffi/index.json: \
	packages/py-cffi/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-cffi)

.PHONY: py-colorama
py-colorama: out/py-colorama/index.json
out/py-colorama/index.json: \
	packages/py-colorama/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-colorama)

.PHONY: py-cparser
py-cparser: out/py-cparser/index.json
out/py-cparser/index.json: \
	packages/py-cparser/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/pkgconf/index.json \
	out/py-cffi/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-cparser)

.PHONY: py-cryptography
py-cryptography: out/py-cryptography/index.json
out/py-cryptography/index.json: \
	packages/py-cryptography/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/libunwind/index.json \
	out/llvm16/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/pkgconf/index.json \
	out/py-cffi/index.json \
	out/py-cparser/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-semantic-version/index.json \
	out/py-setuptools/index.json \
	out/py-setuptools-rust/index.json \
	out/py-typing-extensions/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/rust/index.json \
	out/zlib/index.json
	$(call build,py-cryptography)

.PHONY: py-dateutil
py-dateutil: out/py-dateutil/index.json
out/py-dateutil/index.json: \
	packages/py-dateutil/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-dateutil)

.PHONY: py-distro
py-distro: out/py-distro/index.json
out/py-distro/index.json: \
	packages/py-distro/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-distro)

.PHONY: py-docutils
py-docutils: out/py-docutils/index.json
out/py-docutils/index.json: \
	packages/py-docutils/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-docutils)

.PHONY: py-flit
py-flit: out/py-flit/index.json
out/py-flit/index.json: \
	packages/py-flit/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-flit)

.PHONY: py-gpep517
py-gpep517: out/py-gpep517/index.json
out/py-gpep517/index.json: \
	packages/py-gpep517/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-gpep517)

.PHONY: py-hatchling
py-hatchling: out/py-hatchling/index.json
out/py-hatchling/index.json: \
	packages/py-hatchling/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-pathspec/index.json \
	out/py-pluggy/index.json \
	out/py-trove-classifiers/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-hatchling)

.PHONY: py-idna
py-idna: out/py-idna/index.json
out/py-idna/index.json: \
	packages/py-idna/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-idna)

.PHONY: py-imagesize
py-imagesize: out/py-imagesize/index.json
out/py-imagesize/index.json: \
	packages/py-imagesize/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-imagesize)

.PHONY: py-installer
py-installer: out/py-installer/index.json
out/py-installer/index.json: \
	packages/py-installer/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-build/index.json \
	out/py-flit/index.json \
	out/py-packaging/index.json \
	out/py-pep517/index.json \
	out/py-toml/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-installer)

.PHONY: py-jinja2
py-jinja2: out/py-jinja2/index.json
out/py-jinja2/index.json: \
	packages/py-jinja2/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-jinja2)

.PHONY: py-jmespath
py-jmespath: out/py-jmespath/index.json
out/py-jmespath/index.json: \
	packages/py-jmespath/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-jmespath)

.PHONY: py-markupsafe
py-markupsafe: out/py-markupsafe/index.json
out/py-markupsafe/index.json: \
	packages/py-markupsafe/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-markupsafe)

.PHONY: py-packaging
py-packaging: out/py-packaging/index.json
out/py-packaging/index.json: \
	packages/py-packaging/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-packaging)

.PHONY: py-pathspec
py-pathspec: out/py-pathspec/index.json
out/py-pathspec/index.json: \
	packages/py-pathspec/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-pathspec)

.PHONY: py-pep517
py-pep517: out/py-pep517/index.json
out/py-pep517/index.json: \
	packages/py-pep517/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-pep517)

.PHONY: py-pluggy
py-pluggy: out/py-pluggy/index.json
out/py-pluggy/index.json: \
	packages/py-pluggy/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-pathspec/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-pluggy)

.PHONY: py-prompt_toolkit
py-prompt_toolkit: out/py-prompt_toolkit/index.json
out/py-prompt_toolkit/index.json: \
	packages/py-prompt_toolkit/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-prompt_toolkit)

.PHONY: py-pygments
py-pygments: out/py-pygments/index.json
out/py-pygments/index.json: \
	packages/py-pygments/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-hatchling/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-pathspec/index.json \
	out/py-pluggy/index.json \
	out/py-trove-classifiers/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-pygments)

.PHONY: py-requests
py-requests: out/py-requests/index.json
out/py-requests/index.json: \
	packages/py-requests/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-requests)

.PHONY: py-ruamel.yaml
py-ruamel.yaml: out/py-ruamel.yaml/index.json
out/py-ruamel.yaml/index.json: \
	packages/py-ruamel.yaml/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-ruamel.yaml)

.PHONY: py-semantic-version
py-semantic-version: out/py-semantic-version/index.json
out/py-semantic-version/index.json: \
	packages/py-semantic-version/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-semantic-version)

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

.PHONY: py-setuptools-rust
py-setuptools-rust: out/py-setuptools-rust/index.json
out/py-setuptools-rust/index.json: \
	packages/py-setuptools-rust/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-setuptools-scm/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-setuptools-rust)

.PHONY: py-setuptools-scm
py-setuptools-scm: out/py-setuptools-scm/index.json
out/py-setuptools-scm/index.json: \
	packages/py-setuptools-scm/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-setuptools-scm)

.PHONY: py-six
py-six: out/py-six/index.json
out/py-six/index.json: \
	packages/py-six/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-six)

.PHONY: py-snowballstemmer
py-snowballstemmer: out/py-snowballstemmer/index.json
out/py-snowballstemmer/index.json: \
	packages/py-snowballstemmer/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-packaging/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-snowballstemmer)

.PHONY: py-sphinx
py-sphinx: out/py-sphinx/index.json
out/py-sphinx/index.json: \
	packages/py-sphinx/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinx)

.PHONY: py-sphinx_rtd_theme
py-sphinx_rtd_theme: out/py-sphinx_rtd_theme/index.json
out/py-sphinx_rtd_theme/index.json: \
	packages/py-sphinx_rtd_theme/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinx_rtd_theme)

.PHONY: py-sphinxcontrib-applehelp
py-sphinxcontrib-applehelp: out/py-sphinxcontrib-applehelp/index.json
out/py-sphinxcontrib-applehelp/index.json: \
	packages/py-sphinxcontrib-applehelp/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinxcontrib-applehelp)

.PHONY: py-sphinxcontrib-devhelp
py-sphinxcontrib-devhelp: out/py-sphinxcontrib-devhelp/index.json
out/py-sphinxcontrib-devhelp/index.json: \
	packages/py-sphinxcontrib-devhelp/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinxcontrib-devhelp)

.PHONY: py-sphinxcontrib-htmlhelp
py-sphinxcontrib-htmlhelp: out/py-sphinxcontrib-htmlhelp/index.json
out/py-sphinxcontrib-htmlhelp/index.json: \
	packages/py-sphinxcontrib-htmlhelp/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinxcontrib-htmlhelp)

.PHONY: py-sphinxcontrib-jquery
py-sphinxcontrib-jquery: out/py-sphinxcontrib-jquery/index.json
out/py-sphinxcontrib-jquery/index.json: \
	packages/py-sphinxcontrib-jquery/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinxcontrib-jquery)

.PHONY: py-sphinxcontrib-qthelp
py-sphinxcontrib-qthelp: out/py-sphinxcontrib-qthelp/index.json
out/py-sphinxcontrib-qthelp/index.json: \
	packages/py-sphinxcontrib-qthelp/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinxcontrib-qthelp)

.PHONY: py-sphinxcontrib-serializinghtml
py-sphinxcontrib-serializinghtml: out/py-sphinxcontrib-serializinghtml/index.json
out/py-sphinxcontrib-serializinghtml/index.json: \
	packages/py-sphinxcontrib-serializinghtml/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-sphinxcontrib-serializinghtml)

.PHONY: py-toml
py-toml: out/py-toml/index.json
out/py-toml/index.json: \
	packages/py-toml/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-toml)

.PHONY: py-trove-classifiers
py-trove-classifiers: out/py-trove-classifiers/index.json
out/py-trove-classifiers/index.json: \
	packages/py-trove-classifiers/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-trove-classifiers)

.PHONY: py-typing-extensions
py-typing-extensions: out/py-typing-extensions/index.json
out/py-typing-extensions/index.json: \
	packages/py-typing-extensions/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-typing-extensions)

.PHONY: py-urllib3
py-urllib3: out/py-urllib3/index.json
out/py-urllib3/index.json: \
	packages/py-urllib3/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-urllib3)

.PHONY: py-wcwidth
py-wcwidth: out/py-wcwidth/index.json
out/py-wcwidth/index.json: \
	packages/py-wcwidth/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/libffi/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/py-flit/index.json \
	out/py-gpep517/index.json \
	out/py-installer/index.json \
	out/py-setuptools/index.json \
	out/py-wheel/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-wcwidth)

.PHONY: py-wheel
py-wheel: out/py-wheel/index.json
out/py-wheel/index.json: \
	packages/py-wheel/Containerfile \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/musl/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,py-wheel)

.PHONY: python
python: out/python/index.json
out/python/index.json: \
	packages/python/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/bzip2/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libffi/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/sqlite3/index.json \
	out/zlib/index.json
	$(call build,python)

.PHONY: qemu
qemu: out/qemu/index.json
out/qemu/index.json: \
	packages/qemu/Containerfile \
	out/alsa-lib/index.json \
	out/argp-standalone/index.json \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/binutils/index.json \
	out/bison/index.json \
	out/busybox/index.json \
	out/curl/index.json \
	out/dtc/index.json \
	out/filesystem/index.json \
	out/flex/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/git/index.json \
	out/glib/index.json \
	out/gzip/index.json \
	out/libaio/index.json \
	out/libcap-ng/index.json \
	out/libffi/index.json \
	out/libseccomp/index.json \
	out/libtool/index.json \
	out/libzstd/index.json \
	out/linux-headers/index.json \
	out/lzo/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/meson/index.json \
	out/musl/index.json \
	out/musl-fts/index.json \
	out/musl-obstack/index.json \
	out/ncurses/index.json \
	out/ninja/index.json \
	out/numactl/index.json \
	out/openssh/index.json \
	out/openssl/index.json \
	out/pcre2/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/py-alabaster/index.json \
	out/py-babel/index.json \
	out/py-certifi/index.json \
	out/py-docutils/index.json \
	out/py-idna/index.json \
	out/py-imagesize/index.json \
	out/py-jinja2/index.json \
	out/py-markupsafe/index.json \
	out/py-packaging/index.json \
	out/py-pygments/index.json \
	out/py-requests/index.json \
	out/py-snowballstemmer/index.json \
	out/py-sphinx/index.json \
	out/py-sphinx_rtd_theme/index.json \
	out/py-sphinxcontrib-applehelp/index.json \
	out/py-sphinxcontrib-devhelp/index.json \
	out/py-sphinxcontrib-htmlhelp/index.json \
	out/py-sphinxcontrib-jquery/index.json \
	out/py-sphinxcontrib-qthelp/index.json \
	out/py-sphinxcontrib-serializinghtml/index.json \
	out/py-urllib3/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,qemu)

.PHONY: re2c
re2c: out/re2c/index.json
out/re2c/index.json: \
	packages/re2c/Containerfile \
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
	out/python/index.json
	$(call build,re2c)

.PHONY: readline
readline: out/readline/index.json
out/readline/index.json: \
	packages/readline/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/ncurses/index.json \
	out/pkgconf/index.json
	$(call build,readline)

.PHONY: redis
redis: out/redis/index.json
out/redis/index.json: \
	packages/redis/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json
	$(call build,redis)

.PHONY: rhash
rhash: out/rhash/index.json
out/rhash/index.json: \
	packages/rhash/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json
	$(call build,rhash)

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
	out/llvm13/index.json \
	out/llvm16/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/py-setuptools/index.json \
	out/python/index.json \
	out/zlib/index.json
	$(call build,rust)

.PHONY: samurai
samurai: out/samurai/index.json
out/samurai/index.json: \
	packages/samurai/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/pkgconf/index.json
	$(call build,samurai)

.PHONY: scdoc
scdoc: out/scdoc/index.json
out/scdoc/index.json: \
	packages/scdoc/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,scdoc)

.PHONY: sdtool
sdtool: out/sdtool/index.json
out/sdtool/index.json: \
	packages/sdtool/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/linux-headers/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,sdtool)

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

.PHONY: skalibs
skalibs: out/skalibs/index.json
out/skalibs/index.json: \
	packages/skalibs/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,skalibs)

.PHONY: sops
sops: out/sops/index.json
out/sops/index.json: \
	packages/sops/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,sops)

.PHONY: sqlite3
sqlite3: out/sqlite3/index.json
out/sqlite3/index.json: \
	packages/sqlite3/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/tcl/index.json
	$(call build,sqlite3)

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

.PHONY: talosctl
talosctl: out/talosctl/index.json
out/talosctl/index.json: \
	packages/talosctl/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,talosctl)

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

.PHONY: tcl
tcl: out/tcl/index.json
out/tcl/index.json: \
	packages/tcl/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/pkgconf/index.json
	$(call build,tcl)

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

.PHONY: tflint
tflint: out/tflint/index.json
out/tflint/index.json: \
	packages/tflint/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,tflint)

.PHONY: tofu
tofu: out/tofu/index.json
out/tofu/index.json: \
	packages/tofu/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,tofu)

.PHONY: tpm2-tools
tpm2-tools: out/tpm2-tools/index.json
out/tpm2-tools/index.json: \
	packages/tpm2-tools/Containerfile \
	out/autoconf/index.json \
	out/autoconf-archive/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/curl/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/tpm2-tss/index.json \
	out/util-linux/index.json
	$(call build,tpm2-tools)

.PHONY: tpm2-tss
tpm2-tss: out/tpm2-tss/index.json
out/tpm2-tss/index.json: \
	packages/tpm2-tss/Containerfile \
	out/autoconf/index.json \
	out/autoconf-archive/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/curl/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/json-c/index.json \
	out/libtool/index.json \
	out/linux-headers/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/perl/index.json \
	out/pkgconf/index.json \
	out/util-linux/index.json
	$(call build,tpm2-tss)

.PHONY: unixodbc
unixodbc: out/unixodbc/index.json
out/unixodbc/index.json: \
	packages/unixodbc/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/postgresql/index.json
	$(call build,unixodbc)

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

.PHONY: util-macros
util-macros: out/util-macros/index.json
out/util-macros/index.json: \
	packages/util-macros/Containerfile \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gawk/index.json \
	out/gcc/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/pkgconf/index.json
	$(call build,util-macros)

.PHONY: utmps
utmps: out/utmps/index.json
out/utmps/index.json: \
	packages/utmps/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/skalibs/index.json
	$(call build,utmps)

.PHONY: xmlto
xmlto: out/xmlto/index.json
out/xmlto/index.json: \
	packages/xmlto/Containerfile \
	out/autoconf/index.json \
	out/automake/index.json \
	out/bash/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/docbook-xsl/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/glib/index.json \
	out/libtool/index.json \
	out/libxml2/index.json \
	out/libxslt/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/perl-pod-parser/index.json \
	out/perl-yaml-syck/index.json \
	out/zlib/index.json
	$(call build,xmlto)

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
	out/autoconf/index.json \
	out/automake/index.json \
	out/binutils/index.json \
	out/busybox/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/gettext/index.json \
	out/libtool/index.json \
	out/m4/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/perl/index.json \
	out/po4a/index.json
	$(call build,xz)

.PHONY: yq
yq: out/yq/index.json
out/yq/index.json: \
	packages/yq/Containerfile \
	out/busybox/index.json \
	out/ca-certificates/index.json \
	out/filesystem/index.json \
	out/go/index.json
	$(call build,yq)

.PHONY: zig
zig: out/zig/index.json
out/zig/index.json: \
	packages/zig/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/clang16/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/libzstd/index.json \
	out/lld/index.json \
	out/llvm16/index.json \
	out/make/index.json \
	out/musl/index.json \
	out/openssl/index.json \
	out/zlib/index.json
	$(call build,zig)

.PHONY: zip
zip: out/zip/index.json
out/zip/index.json: \
	packages/zip/Containerfile \
	out/binutils/index.json \
	out/busybox/index.json \
	out/cmake/index.json \
	out/filesystem/index.json \
	out/gcc/index.json \
	out/make/index.json \
	out/musl/index.json
	$(call build,zip)

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

