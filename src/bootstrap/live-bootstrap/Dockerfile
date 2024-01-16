ARG REGISTRY=local
ARG VERSION=fc6eeb6bd75ea0d0025a79ea9fe45614bd60ba14
ARG SRC_SITE=https://codeload.github.com/lrvick/live-bootstrap/legacy.tar.gz
ARG SRC_HASH=0c268b19cf9f4eefdaf45dab64ac393ccf8ee43de58f0721624cab358044bf78
FROM debian@sha256:bac353db4cc04bc672b14029964e686cd7bad56fe34b51f432c1a1304b9928da as debian
FROM ${REGISTRY}/stage0 as stage0

FROM debian as fetch
ARG VERSION
ENV VERSION=${VERSION}
ARG SRC_SITE
ENV SRC_SITE=${SRC_SITE}
ARG SRC_HASH
ENV SRC_HASH=${SRC_HASH}
RUN apt update && apt install -y curl gcc
RUN set -eux; \
    curl ${SRC_SITE}/${VERSION} -o live-bootstrap.tar.gz; \
    echo "${SRC_HASH}  live-bootstrap.tar.gz" | sha256sum -c; \
    tar -xvf live-bootstrap.tar.gz; \
    mv lrvick-live-bootstrap-* live-bootstrap
WORKDIR live-bootstrap
RUN ./download-distfiles.sh
RUN set -eux; \
    mkdir -p /rootfs; \
    mv steps distfiles seed/* /rootfs/
RUN echo "\
FORCE_TIMESTAMPS=False\n\
CHROOT=True\n\
UPDATE_CHECKSUMS=False\n\
JOBS=10\n\
SWAP_SIZE=0\n\
FINAL_JOBS=10\n\
INTERNAL_CI=False\n\
INTERACTIVE=False\n\
BARE_METAL=False\n\
EXTERNAL_SOURCES=True\n\
DISK=sda1\n\
KERNEL_BOOTSTRAP=False\n\
BUILD_KERNELS=False\
" > /rootfs/steps/bootstrap.cfg
RUN cat /rootfs/steps/bootstrap.cfg

FROM scratch as build
COPY --from=stage0 / .
COPY --from=fetch /rootfs .
ENV ARCH_DIR=x86
ENV ARCH=x86
RUN ["/x86/bin/kaem","--verbose","--strict","--file","./after.kaem"]

FROM build as install
ENV PATH=/bin:/usr/sbin:/usr/bin
RUN set -eux; \
    rm -rf /usr/lib/python*/__pycache__; \
    mkdir -p /rootfs/etc /rootfs/home/user; \
    cp -R $(ls -d /etc/* | grep -v '\(resolv.conf\|hosts\)') /rootfs/etc/; \
    cp -R lib usr bin var /rootfs/; \
    echo "user:x:1000:" > /rootfs/etc/group; \
    echo "user:x:1000:1000::/home/user:/bin/bash" > /rootfs/etc/passwd; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
USER 1000:1000
ENTRYPOINT ["/bin/bash"]
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV SOURCE_DATE_EPOCH=1
ENV KCONFIG_NOTIMESTAMP=1
ENV PS1="bootstrap$ "
