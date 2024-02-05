ARG REGISTRY=local
FROM ${REGISTRY}/python as python
FROM ${REGISTRY}/py-setuptools as py-setuptools
FROM ${REGISTRY}/zlib as zlib

FROM busybox as base
ENV VERSION=1.3.1
ENV SRC_FILE=meson-${VERSION}.tar.gz
ENV SRC_SITE=https://github.com/mesonbuild/meson/releases/download/${VERSION}/${SRC_FILE}
ENV SRC_HASH=6020568bdede1643d4fb41e28215be38eff5d52da28ac7d125457c59e0032ad7
COPY --from=python . /
COPY --from=py-setuptools . /
COPY --from=zlib . /

FROM base as fetch
RUN set -eux; \
    wget ${SRC_SITE}; \
    echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xf ${SRC_FILE}
WORKDIR meson-${VERSION}
RUN python setup.py build;

FROM build as install
USER 0:0
RUN set -eux; \
    python setup.py install --root=/rootfs; \
    find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
