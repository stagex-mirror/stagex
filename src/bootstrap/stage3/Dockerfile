ARG REGISTRY=local
FROM ${REGISTRY}/stage2 as stage2

FROM stage2 as base
ENV TARGET=x86_64-linux-musl
ENV BUILD=i386-unknown-linux-musl
ENV MUSL_VERSION 1.2.4
ENV MUSL_SITE http://musl.libc.org/releases
ENV MUSL_FILE musl-${MUSL_VERSION}.tar.gz
ENV MUSL_HASH 7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039
ENV MUSL_DIR=${HOME}/build-musl
ENV BASH_SITE=https://ftp.gnu.org/gnu/bash
ENV BASH_VERSION_=5.2.21
ENV BASH_HASH c8e31bdc59b69aaffc5b36509905ba3e5cbb12747091d27b4b977f078560d5b8
ENV BASH_FILE bash-${BASH_VERSION_}.tar.gz
ENV BASH_DIR=${HOME}/build-bash
ENV COREUTILS_SITE=https://ftp.gnu.org/gnu/coreutils
ENV COREUTILS_VERSION=9.4
ENV COREUTILS_HASH 5f600d9093973b0afe25393d9bc18c44f2232657f4ca0d95ea31c702eb66b739
ENV COREUTILS_FILE coreutils-${COREUTILS_VERSION}.tar.gz
ENV COREUTILS_DIR=${HOME}/build-coreutils

FROM base as fetch
WORKDIR /home/user
RUN set -eux; \
    curl --insecure -OJ ${MUSL_SITE}/${MUSL_FILE}; \
    echo "${MUSL_HASH}  ${MUSL_FILE}" | sha256sum -c; \
    curl --insecure -OJ ${BASH_SITE}/${BASH_FILE}; \
    echo "${BASH_HASH}  ${BASH_FILE}" | sha256sum -c; \
    curl --insecure -OJ ${COREUTILS_SITE}/${COREUTILS_FILE}; \
    echo "${COREUTILS_HASH}  ${COREUTILS_FILE}" | sha256sum -c

FROM fetch as build
RUN set -eux; \
    tar -xzf ${MUSL_FILE}; \
    tar -xzf ${BASH_FILE}; \
    tar -xzf ${COREUTILS_FILE}
WORKDIR ${MUSL_DIR}
RUN set -eux; \
    ../musl-${MUSL_VERSION}/configure \
        --prefix= \
        --build=${BUILD} \
        --host=${TARGET}; \
    make
WORKDIR ${BASH_DIR}
RUN set -eux; \
    echo "${BASH_VERSION_}"; \
    ../bash-${BASH_VERSION_}/configure \
        --build=${BUILD} \
        --host=${TARGET} \
        --prefix=/usr \
        --bindir=/bin \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --disable-nls \
        --enable-readline \
        --without-curses \
        --without-bash-malloc; \
    make

WORKDIR ${COREUTILS_DIR}
RUN set -eux; \
    echo "${COREUTILS_VERSION}"; \
    ../coreutils-${COREUTILS_VERSION}/configure \
        --build=${BUILD} \
        --host=${TARGET} \
        --prefix=/usr \
        --bindir=/bin \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --disable-nls \
        --enable-single-binary=symlinks; \
    make

FROM build as install
USER 0:0
RUN set -eux; \
    env -C ${MUSL_DIR} make DESTDIR=/rootfs install; \
    env -C ${BASH_DIR} make DESTDIR=/rootfs install; \
    env -C ${COREUTILS_DIR} make DESTDIR=/rootfs install; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
USER 1000:1000
ENTRYPOINT ["/bin/bash"]
ENV PATH=/x86_64-linux-musl/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV USER=user
ENV HOME=/home/user
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV SOURCE_DATE_EPOCH=1
ENV KCONFIG_NOTIMESTAMP=1
ENV PS1="stage3 $ "
