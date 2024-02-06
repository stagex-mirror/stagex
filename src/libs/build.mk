out/libxml2.tar: \
	out/busybox.tar \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar \
	out/make.tar \
	out/bash.tar \
	out/python.tar \
	out/sed.tar \
	out/m4.tar \
	out/autoconf.tar \
	out/automake.tar \
	out/pkgconf.tar \
	out/libtool.tar
	$(call build,libs,libxml2)

out/ca-certificates.tar:
	$(call build,libs,ca-certificates)
