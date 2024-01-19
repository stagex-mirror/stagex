ARG REGISTRY=local
FROM ${REGISTRY}/live-bootstrap:latest as live-bootstrap

FROM live-bootstrap as base
ENV TARGET=x86_64-linux-musl
ENV GCC_VERSION 13.1.0
ENV GCC_SRC_FILE gcc-$GCC_VERSION.tar.xz
ENV GCC_SRC_SITE https://mirrors.kernel.org/gnu/gcc/gcc-${GCC_VERSION}
ENV GCC_SRC_HASH 61d684f0aa5e76ac6585ad8898a2427aade8979ed5e7f85492286c4dfc13ee86
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
RUN set -eux; \
    tar -xf ${GCC_SRC_FILE}; \
    cd gcc-${GCC_VERSION}; \
    mv ../*.tar.* .; \
    ./contrib/download_prerequisites
ENV PATH=/home/user/gcc-build/bin:${PATH}
RUN set -eux; \
    mkdir -p gcc-build/bin; \
    cd gcc-build; \
    ln -s /usr/sbin/ar bin/${TARGET}-ar; \
    ln -s /usr/sbin/ranlib bin/${TARGET}-ranlib; \
    ../gcc-${GCC_VERSION}/configure \
        --build=i386-unknown-linux-musl \
        --host=i386-unknown-linux-musl \
        --target=${TARGET} \
        --libdir=/lib \
        --prefix= \
        --enable-languages=c,c++ \
        --disable-nls \
        --disable-shared \
        --without-headers \
        --with-as=/usr/sbin/as \
        --disable-multilib \
        --disable-libquadmath \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libssp \
        --disable-libvtv \
        --disable-gcov \
        --disable-libstdcxx \
        --disable-werror \
        --disable-threads \
        --disable-separate-code \
        --enable-deterministic-archives; \
    make -j "$(nproc)" || :


FROM build as install
USER 0:0
WORKDIR /home/user/gcc-build
RUN set -eux; \
    make DESTDIR="/rootfs" install; \
    cp /lib/ld-musl-i386.so.1 /rootfs/lib/; \
    ln -s /lib/ld-musl-i386.so.1 /rootfs/lib/libc.so; \
    find /rootfs -exec touch -hcd "@0" "{}" +

#FROM install as package
FROM scratch as package
COPY --from=install /rootfs /
ENTRYPOINT ["/bin/x86_64-linux-musl-gcc"]
CMD ["--version"]
