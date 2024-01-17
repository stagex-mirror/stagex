ARG REGISTRY=local
FROM ${REGISTRY}/live-bootstrap:latest as live-bootstrap

FROM live-bootstrap as base
ENV TARGET=x86_64-linux-musl
ENV BINUTILS_VERSION 2.41
ENV BINUTILS_SRC_SITE https://ftp.gnu.org/gnu/binutils
ENV BINUTILS_SRC_HASH ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450
ENV GCC_VERSION 12.2.0
ENV GCC_SRC_FILE gcc-$GCC_VERSION.tar.xz
ENV GCC_SRC_SITE https://mirrors.kernel.org/gnu/gcc/gcc-${GCC_VERSION}
ENV GCC_SRC_HASH e549cf9cf3594a00e27b6589d4322d70e0720cdd213f39beb4181e06926230ff
ENV GCC_DEP_SITE https://gcc.gnu.org/pub/gcc/infrastructure/
ENV GMP_FILE gmp-6.2.1.tar.bz2
ENV GMP_HASH eae9326beb4158c386e39a356818031bd28f3124cf915f8c5b1dc4c7a36b4d7c
ENV MPFR_FILE mpfr-4.1.0.tar.bz2
ENV MPFR_HASH feced2d430dd5a97805fa289fed3fc8ff2b094c02d05287fd6133e7f1f0ec926
ENV MPC_FILE mpc-1.2.1.tar.gz
ENV MPC_HASH 17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459
ENV ISL_FILE isl-0.24.tar.bz2
ENV ISL_HASH fcf78dd9656c10eb8cf9fbd5f59a0b6b01386205fe1934b3b287a0a1898145c0

FROM base as fetch
WORKDIR /home/user
RUN set -eux; \
    curl -OJ ${BINUTILS_SRC_SITE}/binutils-${BINUTILS_VERSION}.tar.xz; \
    echo "${BINUTILS_SRC_HASH} binutils-${BINUTILS_VERSION}.tar.xz" | sha256sum -c; \
    curl -OJ ${GCC_SRC_SITE}/${GCC_SRC_FILE}; \
    echo "${GCC_SRC_HASH}  ${GCC_SRC_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${GMP_FILE}; \
    echo "${GMP_HASH}  ${GMP_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${MPFR_FILE}; \
    echo "${MPFR_HASH}  ${MPFR_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${MPC_FILE}; \
    echo "${MPC_HASH}  ${MPC_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${ISL_FILE}; \
    echo "${ISL_HASH}  ${ISL_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xf binutils-${BINUTILS_VERSION}.tar.xz
RUN set -ex; \
    cd binutils-${BINUTILS_VERSION}; \
    ./configure \
        --target=${TARGET} \
        --libdir=/lib \
        --with-sysroot= \
        --prefix= \
        --disable-multilib \
        --disable-separate-code \
        --disable-werror \
        --enable-deterministic-archives; \
	make -j "$(nproc)"
#RUN tar -xf ${GCC_SRC_FILE}
#RUN set -eux; \
#    cd gcc-${GCC_VERSION}; \
#    mv ../*.tar.* .; \
#    ./contrib/download_prerequisites; \
#    ./configure \
#        --target=${TARGET} \
#        --prefix=/usr \
#        --mandir=/usr/share/man \
#        --infodir=/usr/share/info \
#        --libdir=/usr/lib \
#        --disable-nls \
#        --without-headers \
#        --enable-languages=c,c++; \
#make -j "$(nproc)"


FROM build as package

#FROM build as install
#USER 0:0
#RUN make DESTDIR="/rootfs" install;
#RUN find /rootfs -exec touch -hcd "@0" "{}" +
#
#FROM scratch as package
#COPY --from=install /rootfs /
#ENTRYPOINT ["/bin/ld"]
#CMD ["--version"]
