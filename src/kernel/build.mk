.PHONY: linux
linux: \
	out/linux-generic.tgz

out/linux-generic.tgz: \
	out/gcc.tgz \
	out/binutils.tgz \
	out/make.tgz \
	out/musl.tgz \
	out/bison.tgz \
	out/pkgconf.tgz \
	out/libzstd.tgz \
	out/openssl.tgz \
	out/perl.tgz \
	out/zlib.tgz \
	out/flex.tgz \
	out/elfutils.tgz
	$(call build,kernel,linux-generic)
