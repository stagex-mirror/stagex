ARG REGISTRY=local
FROM ${REGISTRY}/busybox as busybox
FROM ${REGISTRY}/gcc as gcc
FROM ${REGISTRY}/binutils as binutils
FROM ${REGISTRY}/musl as musl
FROM ${REGISTRY}/make as make
FROM ${REGISTRY}/autoconf as autoconf
FROM ${REGISTRY}/automake as automake
FROM ${REGISTRY}/m4 as m4

FROM busybox as base
ENV VERSION=1.5.0
ENV SRC_FILE=${VERSION}.tar.gz
ENV SRC_SITE=https://github.com/argp-standalone/argp-standalone/archive/refs/tags/${SRC_FILE}
ENV SRC_HASH=c29eae929dfebd575c38174f2c8c315766092cec99a8f987569d0cad3c6d64f6
COPY --from=gcc . /
COPY --from=binutils . /
COPY --from=make . /
COPY --from=musl . /
COPY --from=autoconf . /
COPY --from=automake . /
COPY --from=m4 . /

FROM base as fetch
RUN wget ${SRC_SITE}
RUN echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xf ${SRC_FILE}
WORKDIR argp-standalone-${VERSION}
RUN ls -lah
RUN set -eux; \
    autoreconf -vif; \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --localstatedir=/var; \
    make

FROM build as install
USER 0:0
RUN set -eux; \
    install -D -m644 argp.h /rootfs/usr/include/argp.h; \
    install -D -m755 libargp.a /rootfs/usr/lib/libargp.a; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
