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
ENV VERSION=1.2.7
ENV SRC_FILE=v${VERSION}.tar.gz
ENV SRC_SITE=https://github.com/void-linux/musl-fts/archive/refs/tags/${SRC_FILE}
ENV SRC_HASH=49ae567a96dbab22823d045ffebe0d6b14b9b799925e9ca9274d47d26ff482a6
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
WORKDIR musl-fts-${VERSION}
RUN set -eux; \
    ./bootstrap.sh; \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --sysconfdir=/etc \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --localstatedir=/var; \
    make

FROM build as install
USER 0:0
RUN set -eux; \
    make DESTDIR=/rootfs install; \
    install -Dm644 musl-fts.pc -t /rootfs/usr/lib/pkgconfig/; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
