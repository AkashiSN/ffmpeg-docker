# syntax = docker/dockerfile:1.5

ARG FFMPEG_VERSION="6.0"
FROM akashisn/ffmpeg:${FFMPEG_VERSION} AS ffmpeg-linux-image
FROM ghcr.io/akashisn/ffmpeg-windows:${FFMPEG_VERSION} AS ffmpeg-windows-image

#
# build env base image
#
FROM ubuntu:22.04 AS build-env

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install ca-certificates
RUN <<EOT
apt-get update
apt-get install -y ca-certificates
rm -rf /var/lib/apt/lists/*
EOT

# Install build tools
RUN <<EOT
sed -i -r 's@http://(jp.)?archive.ubuntu.com/ubuntu/@https://ftp.udx.icscoe.jp/Linux/ubuntu/@g' /etc/apt/sources.list
apt-get update
apt-get install -y \
    autopoint \
    bc \
    build-essential \
    clang \
    cmake \
    curl \
    gettext \
    git \
    git-lfs \
    gperf \
    libtool \
    lzip \
    make \
    meson \
    mingw-w64 \
    mingw-w64-tools \
    nasm \
    p7zip \
    pkg-config \
    python3 \
    ragel \
    subversion \
    wget \
    xxd \
    yasm
EOT

# Clone Implib.so
RUN <<EOT
git clone --filter=blob:none --depth=1 https://github.com/yugr/Implib.so /opt/implib
EOT

# Environment
ARG FFMPEG_VERSION
ENV FFMPEG_VERSION="${FFMPEG_VERSION}" \
    PREFIX="/usr/local" \
    ARTIFACT_DIR="/dist" \
    RUNTIME_LIB_DIR="/runtime" \
    WORKDIR="/workdir"
WORKDIR ${WORKDIR}

# Copy build script
ADD ./scripts/base.sh ./


#
# ffmpeg library build stage
#
FROM build-env AS ffmpeg-library-build

# Environment
ARG TARGET_OS="Linux"
ENV TARGET_OS=${TARGET_OS} \
    RUNTIME_LIB_DIR=${ARTIFACT_DIR}${RUNTIME_LIB_DIR}

# Copy build script
ADD ./scripts/build-library.sh ./

# Run build
RUN bash ./build-library.sh


#
# final ffmpeg-library image
#
FROM scratch AS ffmpeg-library

COPY --from=ffmpeg-library-build /dist /


#
# ffmpeg linux binary build stage
#
FROM build-env AS ffmpeg-linux-build

# Environment
ENV TARGET_OS="Linux"

# Copy build script
ADD ./scripts/build-ffmpeg.sh ./

# Copy ffmpeg-library image
COPY --from=ghcr.io/akashisn/ffmpeg-library:linux / /

# Build ffmpeg
RUN bash ./build-ffmpeg.sh

# Copy run.sh
COPY --chmod=755 <<'EOT' ${ARTIFACT_DIR}/${PREFIX}/run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib/dri
export LIBVA_DRIVER_NAME=iHD
exec $@
EOT


#
# final ffmpeg-linux image
#
FROM ubuntu:22.04 AS ffmpeg-linux

SHELL ["/bin/sh", "-e", "-c"]

# Environment
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/local/lib \
    LIBVA_DRIVERS_PATH=/usr/local/lib/dri \
    LIBVA_DRIVER_NAME=iHD

# Copy ffmpeg
COPY --from=ffmpeg-linux-build /dist /

# Run ldconfig
RUN ldconfig

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]


#
# ffmpeg windows binary build image
#
FROM build-env AS ffmpeg-windows-build

# Environment
ENV TARGET_OS="Windows"

# Copy build script
ADD ./scripts/build-ffmpeg.sh ./

# Copy ffmpeg-library image
COPY --from=ghcr.io/akashisn/ffmpeg-library:windows / /

# Build ffmpeg
RUN bash ./build-ffmpeg.sh


#
# final ffmpeg-windows image
#
FROM scratch AS ffmpeg-windows

COPY --from=ffmpeg-windows-build /dist /


#
# export image
#
FROM scratch AS ffmpeg-linux-export

COPY --from=ffmpeg-linux-image /usr/local/bin /bin
COPY --from=ffmpeg-linux-image /usr/local/lib /lib
COPY --from=ffmpeg-linux-image /usr/local/configure_options /
COPY --from=ffmpeg-linux-image /usr/local/run.sh /


#
# export windws exe
#
FROM scratch AS ffmpeg-windows-export

COPY --from=ffmpeg-windows-image /usr/local /


#
# vainfo build image
#
FROM ubuntu:22.04 AS vainfo-build

SHELL ["/bin/bash", "-e", "-c"]

# Copy ffmpeg-library image
COPY --from=ghcr.io/akashisn/ffmpeg-library:linux / /

# Copy vainfo library
RUN <<EOT
mkdir -p /dist
cp --archive --parents --no-dereference /usr/local/bin/vainfo /dist
cd /runtime
cp --archive --parents --no-dereference usr/local/lib/libpciaccess.so* /dist
cp --archive --parents --no-dereference usr/local/lib/libva{,-drm}.so* /dist
cp --archive --parents --no-dereference usr/local/lib/libdrm*.so* /dist
cp --archive --parents --no-dereference usr/local/lib/libigdgmm.so* /dist
cp --archive --parents --no-dereference usr/local/lib/dri /dist
EOT


#
# vainfo image
#
FROM ubuntu:22.04 AS vainfo

SHELL ["/bin/bash", "-e", "-c"]

# Environment
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/local/lib \
    LIBVA_DRIVERS_PATH=/usr/local/lib/dri \
    LIBVA_DRIVER_NAME=iHD

# Copy ffmpeg-library image
COPY --from=vainfo-build /dist /

# Run ldconfig
RUN ldconfig

WORKDIR /workdir
ENTRYPOINT [ "/usr/local/bin/vainfo" ]
