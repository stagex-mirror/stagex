ARG REGISTRY=local
FROM ${REGISTRY}/gcc:latest as gcc
FROM ${REGISTRY}/binutils:latest as binutils
FROM ${REGISTRY}/musl:latest as musl
FROM ${REGISTRY}/make:latest as make
FROM ${REGISTRY}/busybox:latest as busybox

FROM busybox as base
COPY --from=gcc . /
COPY --from=binutils . /
COPY --from=make . /
COPY --from=musl . /
ENV SRC_SITE=https://ftp.gnu.org/gnu/m4
ENV SRC_VERSION=1.4.18
ENV SRC_HASH=ab2633921a5cd38e48797bf5521ad259bdc4b979078034a3b790d7fec5493fab

FROM base as fetch
RUN wget ${SRC_SITE}/m4-${SRC_VERSION}.tar.gz
RUN echo "${SRC_HASH}  m4-${SRC_VERSION}.tar.gz" | sha256sum -c

FROM fetch as build
RUN tar -xzf m4-${SRC_VERSION}.tar.gz
WORKDIR m4-${SRC_VERSION}
RUN set -eux; \
    ./configure \
        --prefix=/usr; \
    make;

FROM build as install
USER 0:0
RUN make DESTDIR=/rootfs install
COPY --from=musl /usr/lib/libc.so /rootfs/lib/ld-musl-x86_64.so.1
RUN find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
ENTRYPOINT ["/usr/bin/m4"]
CMD ["--version"]
