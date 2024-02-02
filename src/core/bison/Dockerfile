ARG REGISTRY=local
FROM ${REGISTRY}/gcc:latest as gcc
FROM ${REGISTRY}/binutils:latest as binutils
FROM ${REGISTRY}/musl:latest as musl
FROM ${REGISTRY}/make:latest as make
FROM ${REGISTRY}/busybox:latest as busybox

FROM busybox as base
ENV SRC_SITE https://ftp.gnu.org/gnu/bison
ENV SRC_VERSION 3.8.2
ENV SRC_HASH 06c9e13bdf7eb24d4ceb6b59205a4f67c2c7e7213119644430fe82fbd14a0abb
ENV SRC_FILE bison-${SRC_VERSION}.tar.gz

FROM base as fetch
RUN set -eux; \
    wget ${SRC_SITE}/${SRC_FILE}; \
    echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xf ${SRC_FILE}
WORKDIR bison-${SRC_VERSION}
COPY --from=gcc . /
COPY --from=binutils . /
COPY --from=make . /
COPY --from=musl . /
ENV M4=/usr/bin/m4
RUN set -eux; \
    ./configure \
        --prefix=/usr; \
    make

from build as install
USER 0:0
RUN make DESTDIR=/rootfs install
RUN find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
ENTRYPOINT ["/usr/bin/bison"]
CMD ["--version"]
