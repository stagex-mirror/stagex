ARG REGISTRY=local
from ${REGISTRY}/binutils as binutils
from ${REGISTRY}/m4 as m4
from ${REGISTRY}/lex as lex
from ${REGISTRY}/gcc as gcc
from ${REGISTRY}/musl as musl
from ${REGISTRY}/make as make
from ${REGISTRY}/libtool as libtool
from ${REGISTRY}/autoconf as autoconf
from ${REGISTRY}/automake as automake
from ${REGISTRY}/gettext as gettext
from ${REGISTRY}/bison as bison
from ${REGISTRY}/busybox as busybox

FROM busybox as base
ENV SRC_VERSION=2.5.11
ENV SRC_SITE=http://download.nust.na/pub2/openpkg1/sources/DST/flex/flex-2.5.11.tar.gz
ENV SRC_HASH=bc79b890f35ca38d66ff89a6e3758226131e51ccbd10ef78d5ff150b7bd73689
ENV SRC_FILE=flex-${SRC_VERSION}.tar.gz

FROM base as fetch
RUN set -eux; \
    wget ${SRC_SITE}; \
    echo "${SRC_HASH}  ${SRC_FILE}" | sha256sum -c

FROM fetch as build
RUN tar -xzf ${SRC_FILE}
WORKDIR flex-${VERSION}
COPY --from=gcc . /
COPY --from=binutils . /
COPY --from=make . /
COPY --from=m4 . /
COPY --from=libtool . /
COPY --from=autoconf . /
COPY --from=automake . /
COPY --from=bison . /
COPY --from=gettext . /
COPY --from=musl . /
RUN set -eux; \
    ./autogen.sh; \
    ./configure \
        --build=x86_64-unknown-linux-musl \
        --host=x86_64-unknown-linux-musl \
        --prefix=/usr \
        --bindir=/bin \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --disable-shared \
        --disable-static; \
    make

FROM build as install
USER 0:0
RUN make DESTDIR=/rootfs install
RUN find /rootfs -exec touch -hcd "@0" "{}" +

FROM scratch as package
COPY --from=install /rootfs /
ENTRYPOINT ["/bin/flex"]
CMD ["--version"]
