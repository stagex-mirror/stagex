ARG REGISTRY=local
FROM ${REGISTRY}/busybox as busybox
FROM ${REGISTRY}/gcc as gcc
FROM ${REGISTRY}/binutils as binutils
FROM ${REGISTRY}/musl as musl
FROM ${REGISTRY}/make as make
FROM ${REGISTRY}/autoconf as autoconf
FROM ${REGISTRY}/automake as automake
FROM ${REGISTRY}/libtool as libtool
FROM ${REGISTRY}/m4 as m4
FROM ${REGISTRY}/pkgconf as pkgconf

FROM busybox as base
ENV VERSION=1.2.3
ENV SRC_FILE=v${VERSION}.tar.gz
ENV SRC_SITE=https://github.com/void-linux/musl-obstack/archive/refs/tags/${SRC_FILE}
ENV SRC_HASH=9ffb3479b15df0170eba4480e51723c3961dbe0b461ec289744622db03a69395
COPY --from=gcc . /
COPY --from=binutils . /
COPY --from=make . /
COPY --from=musl . /
COPY --from=autoconf . /
COPY --from=automake . /
COPY --from=libtool . /
COPY --from=pkgconf . /
COPY --from=m4 . /

FROM base as fetch
RUN wget ${SRC_SITE}
RUN echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xzf ${SRC_FILE}
WORKDIR musl-obstack-${VERSION}
RUN set -eux; \
    ./bootstrap.sh; \
    ./configure --prefix=/usr; \
    make

FROM build as install
USER 0:0
RUN set -eux; \
    make DESTDIR=/rootfs install; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
