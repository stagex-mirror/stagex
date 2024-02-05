FROM stagex/busybox as base
ENV VERSION=0.190
ENV SRC_FILE=elfutils-${VERSION}.tar.bz2
ENV SRC_SITE=https://sourceware.org/elfutils/ftp/${VERSION}/${SRC_FILE}
ENV SRC_HASH=8e00a3a9b5f04bc1dc273ae86281d2d26ed412020b391ffcc23198f10231d692
COPY --from=stagex/gcc . /
COPY --from=stagex/binutils . /
COPY --from=stagex/make . /
COPY --from=stagex/bison . /
COPY --from=stagex/libtool . /
COPY --from=stagex/zlib . /
COPY --from=stagex/libzstd . /
COPY --from=stagex/flex . /
COPY --from=stagex/autoconf . /
COPY --from=stagex/automake . /
COPY --from=stagex/pkgconf . /
COPY --from=stagex/gettext . /
COPY --from=stagex/m4 . /
COPY --from=stagex/argp-standalone . /
COPY --from=stagex/musl . /
COPY --from=stagex/musl-fts . /
COPY --from=stagex/musl-obstack . /
COPY --from=stagex/linux-headers . /

FROM base as fetch
RUN wget --no-check-certificate ${SRC_SITE} -O ${SRC_FILE}
RUN echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN set -eux; \
    tar -xjf ${SRC_FILE}
WORKDIR elfutils-${VERSION}
ADD *.patch .
RUN set -eux; \
    patch -p1 < musl-macros.patch; \
    autoreconf -vif; \
    CFLAGS="-D_GNU_SOURCE -Wno-error -Wno-null-dereference" \
    ./configure \
        --build="x86_64-linux-musl" \
        --host="x86_64-linux-musl" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --localstatedir=/var \
        --program-prefix=eu- \
        --enable-deterministic-archives \
        --disable-nls \
	    --disable-progs \
        --disable-libdebuginfod \
        --disable-debuginfod \
        --with-zstd; \
    make

FROM build as install
USER 0:0
RUN set -eux; \
    mkdir -p /rootfs; \
    make DESTDIR=/rootfs install; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
