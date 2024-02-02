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
ENV SRC_VERSION 070527
ENV SRC_FILE heirloom-devtools-${SRC_VERSION}.tar.bz2
ENV SRC_SITE=http://downloads.sourceforge.net/project/heirloom/heirloom-devtools/${SRC_VERSION}/${SRC_FILE}
ENV SRC_HASH=9f233d8b78e4351fe9dd2d50d83958a0e5af36f54e9818521458a08e058691ba

FROM base as fetch
RUN wget ${SRC_SITE}
RUN echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xjf ${SRC_FILE}
WORKDIR heirloom-devtools-${SRC_VERSION}
RUN set -eux; \
    make yacc/Makefile lex/Makefile; \
    make -C yacc LDFLAGS=-static; \
    make -C lex LDFLAGS=-static

FROM build as install
USER 0:0
RUN set -eux; \
    mkdir -p /rootfs/usr/bin; \
    install lex/lex /rootfs/usr/bin
RUN find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
ENTRYPOINT ["/usr/bin/lex"]
CMD ["-V"]
