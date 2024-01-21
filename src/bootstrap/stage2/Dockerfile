ARG REGISTRY=local
FROM ${REGISTRY}/live-bootstrap:latest as live-bootstrap

FROM live-bootstrap as base
ENV TARGET=x86_64-linux-musl
ENV GCC_VERSION 13.1.0
ENV GCC_FILE gcc-$GCC_VERSION.tar.xz
ENV GCC_SITE https://mirrors.kernel.org/gnu/gcc/gcc-${GCC_VERSION}
ENV GCC_HASH 61d684f0aa5e76ac6585ad8898a2427aade8979ed5e7f85492286c4dfc13ee86
ENV GCC_DEP_SITE https://gcc.gnu.org/pub/gcc/infrastructure/
ENV GMP_FILE gmp-6.2.1.tar.bz2
ENV GMP_HASH eae9326beb4158c386e39a356818031bd28f3124cf915f8c5b1dc4c7a36b4d7c
ENV MPFR_FILE mpfr-4.1.0.tar.bz2
ENV MPFR_HASH feced2d430dd5a97805fa289fed3fc8ff2b094c02d05287fd6133e7f1f0ec926
ENV MPC_FILE mpc-1.2.1.tar.gz
ENV MPC_HASH 17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459
ENV ISL_FILE isl-0.24.tar.bz2
ENV ISL_HASH fcf78dd9656c10eb8cf9fbd5f59a0b6b01386205fe1934b3b287a0a1898145c0
ENV MUSL_VERSION 1.2.4
ENV MUSL_SITE http://musl.libc.org
ENV MUSL_FILE musl-${MUSL_VERSION}.tar.gz
ENV MUSL_HASH 7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039
ENV BINUTILS_VERSION 2.41
ENV BINUTILS_SITE https://ftp.gnu.org/gnu/binutils
ENV BINUTILS_FILE binutils-${BINUTILS_VERSION}.tar.xz
ENV BINUTILS_HASH ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450

FROM base as fetch
WORKDIR ${HOME}
RUN set -eux; \
    curl -OJ ${GCC_SITE}/${GCC_FILE}; \
    echo "${GCC_HASH}  ${GCC_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${GMP_FILE}; \
    echo "${GMP_HASH}  ${GMP_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${MPFR_FILE}; \
    echo "${MPFR_HASH}  ${MPFR_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${MPC_FILE}; \
    echo "${MPC_HASH}  ${MPC_FILE}" | sha256sum -c; \
    curl -OJ ${GCC_DEP_SITE}/${ISL_FILE}; \
    echo "${ISL_HASH}  ${ISL_FILE}" | sha256sum -c; \
    curl -OJ ${MUSL_SITE}/releases/${MUSL_FILE}; \
    echo "${MUSL_HASH} ${MUSL_FILE}" | sha256sum -c; \
    curl -OJ ${BINUTILS_SITE}/${BINUTILS_FILE}; \
    echo "${BINUTILS_HASH} ${BINUTILS_FILE}" | sha256sum -c

FROM fetch as extract
RUN set -eux; \
    tar -xzf ${MUSL_FILE}; \
    tar -xf ${BINUTILS_FILE}; \
    tar -xf ${GCC_FILE}; \
    cd gcc-${GCC_VERSION}; \
    mv ../*.tar.* .; \
    ./contrib/download_prerequisites

FROM extract as build
ENV BINUTILS_DIR ${HOME}/build-binutils
ENV GCC_DIR ${HOME}/build-gcc
ENV MUSL_DIR ${HOME}/build-musl
ENV SYSROOT_DIR ${HOME}/build-sysroot

# Phase 1: Build cross binutils in build-binutils
WORKDIR ${BINUTILS_DIR}
RUN set -eux; \
    ../binutils-${BINUTILS_VERSION}/configure \
        --build=i386-unknown-linux-musl \
        --host=i386-unknown-linux-musl \
        --target=${TARGET} \
        --with-sysroot=/${TARGET} \
        --prefix= \
        --libdir=/lib \
        --disable-werror \
        --disable-multilib \
        --disable-gprofng \
        --disable-separate-code \
        --enable-deterministic-archives; \
    make all

# Phase 2: Prepare build sysroot
WORKDIR ${SYSROOT_DIR}
RUN set -eux; \
    mkdir -p include; \
    ln -sf . usr; \
    ln -sf lib lib32; \
    ln -sf lib lib64

# Phase 3: Build gcc (without libgcc) in build-gcc
WORKDIR ${GCC_DIR}
RUN set -eux; \
    ../gcc-${GCC_VERSION}/configure \
        --build=i386-unknown-linux-musl \
        --host=i386-unknown-linux-musl \
        --target=${TARGET} \
        --with-build-sysroot=${SYSROOT_DIR} \
        --with-sysroot=/${TARGET} \
        --prefix= \
        --libdir=/lib \
        --disable-multilib \
        --disable-bootstrap \
        --disable-assembly \
        --disable-libmudflap \
        --disable-libsanitizer \
        --disable-gnu-indirect-function \
        --disable-libmpx \
        --disable-werror \
        --enable-languages=c,c++ \
        --enable-tls \
        --enable-initfini-array \
        --enable-libstdcxx-time=rt \
        --enable-deterministic-archives \
        AR_FOR_TARGET=${BINUTILS_DIR}/binutils/ar \
        AS_FOR_TARGET=${BINUTILS_DIR}/gas/as-new \
        LD_FOR_TARGET=${BINUTILS_DIR}/ld/ld-new \
        NM_FOR_TARGET=${BINUTILS_DIR}/binutils/nm-new \
        OBJCOPY_FOR_TARGET=${BINUTILS_DIR}/binutils/objcopy \
        OBJDUMP_FOR_TARGET=${BINUTILS_DIR}/binutils/objdump \
        RANLIB_FOR_TARGET=${BINUTILS_DIR}/binutils/ranlib \
        READELF_FOR_TARGET=${BINUTILS_DIR}/binutils/readelf \
        STRIP_FOR_TARGET=${BINUTILS_DIR}/binutils/strip-new; \
    make all-gcc

# Phase 4: Install musl libc headers to build-sysroot for use by libgcc
WORKDIR ${MUSL_DIR}
RUN set -eux; \
    ../musl-${MUSL_VERSION}/configure \
        CC="${GCC_DIR}/gcc/xgcc -B ${HOME}/build-gcc/gcc" \
        LIBCC="${GCC_DIR}/${TARGET}/libgcc/libgcc.a" \
        --prefix= \
        --host=x86_64-linux-musl; \
    make DESTDIR=${SYSROOT_DIR} install-headers

# Phase 5: Compile libgcc
WORKDIR ${GCC_DIR}
RUN make MAKE="make enable_shared=no" all-target-libgcc

# Phase 5: Compile musl libc and install to sysroot
WORKDIR ${MUSL_DIR}
RUN set -eux; \
    make \
        AR=${BINUTILS_DIR}/binutils/ar \
        RANLIB=${BINUTILS_DIR}/binutils/ranlib; \
    make DESTDIR=${SYSROOT_DIR} install

# Phase 6: Compile remaining gcc targets
WORKDIR ${GCC_DIR}
RUN make

FROM build as package

FROM build as install
WORKDIR ${HOME}
RUN set -eux; \
    env -C build-musl make DESTDIR=${SYSROOT_DIR} install; \
    env -C build-gcc make DESTDIR=${SYSROOT_DIR} install; \
    env -C build-binutils make DESTDIR=${SYSROOT_DIR} install; \
    find ${SYSROOT_DIR} -exec touch -hcd "@0" "{}" +

FROM live-bootstrap as package
COPY --from=install ${SYSROOT_DIR} /${TARGET}
ENV PS1="stage2 $ "
