FROM stagex/busybox as base
WORKDIR ${HOME}
ENV SRC_SITE http://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/
ENV SRC_VERSION 6.6
ENV SRC_HASH d926a06c63dd8ac7df3f86ee1ffc2ce2a3b81a2d168484e76b5b389aba8e56d0

FROM base as fetch
RUN wget ${SRC_SITE}/linux-${SRC_VERSION}.tar.xz
RUN echo "${SRC_HASH}  linux-${SRC_VERSION}.tar.xz" | sha256sum -c

FROM fetch as build
RUN tar -xf linux-${SRC_VERSION}.tar.xz
WORKDIR linux-${SRC_VERSION}
COPY --from=stagex/musl . /
COPY --from=stagex/make . /
COPY --from=stagex/binutils . /
COPY --from=stagex/linux-headers . /
COPY --from=stagex/elfutils . /
COPY --from=stagex/openssl . /
COPY --from=stagex/perl . /
COPY --from=stagex/m4 . /
COPY --from=stagex/gcc . /
COPY --from=stagex/bison . /
COPY --from=stagex/libzstd . /
COPY --from=stagex/zlib . /
COPY --from=stagex/flex . /
COPY --from=stagex/pkgconf . /
RUN set -eux; \
    make oldconfig
RUN make

FROM build as install
USER 0:0
RUN set -eux; \
    make DESTDIR=/rootfs install; \
    mkdir -p /rootfs/usr; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
