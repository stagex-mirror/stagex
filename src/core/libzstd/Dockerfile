FROM stagex/busybox as base
ENV VERSION=1.5.5
ENV SRC_FILE=v${VERSION}.tar.gz
ENV SRC_SITE=https://github.com/facebook/zstd/archive/${SRC_FILE}
ENV SRC_HASH=98e9c3d949d1b924e28e01eccb7deed865eefebf25c2f21c702e5cd5b63b85e1
COPY --from=stagex/python . /
COPY --from=stagex/gcc . /
COPY --from=stagex/musl . /
COPY --from=stagex/meson . /
COPY --from=stagex/ninja . /
COPY --from=stagex/binutils . /
COPY --from=stagex/pkgconf . /
COPY --from=stagex/zlib . /

FROM base as fetch
RUN set -eux; \
    wget ${SRC_SITE}; \
    echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xf ${SRC_FILE}
WORKDIR zstd-${VERSION}
RUN set -eux; \
    meson env2mfile \
        --native \
        --system=linux \
        --cpu-family=x86_64 \
        --cpu=x86_64 \
        --endian=little \
        -o meson.cross; \
    meson setup \
		--prefix=/usr \
		--libdir=/usr/lib \
		--libexecdir=/usr/libexec \
		--bindir=/usr/bin \
		--sbindir=/usr/sbin \
		--includedir=/usr/include \
		--datadir=/usr/share \
		--mandir=/usr/share/man \
		--infodir=/usr/share/info \
		--localedir=/usr/share/locale \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--sharedstatedir=/var/lib \
		--buildtype=plain \
		--auto-features=auto \
		--wrap-mode=nodownload \
        --default-library=both \
        --cross-file=meson.cross \
        -Dbacktrace=disabled \
		-Db_lto=false \
		-Db_staticpic=true \
		-Db_pie=true \
		-Dpython.bytecompile=0 \
		-Dwerror=false \
        -Db_ndebug=true \
        -Dbin_tests=false \
        -Dbin_contrib=false \
        -Dbin_programs=true \
        -Dbacktrace=disabled \
        -Dmulti_thread=enabled \
        -Dlz4=disabled \
        -Dlzma=disabled \
        -Dzlib=disabled \
        build/meson \
        output; \
    meson compile -C output

FROM build as install
USER 0:0
RUN set -eux; \
    DESTDIR=/rootfs meson install --no-rebuild -C output; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
