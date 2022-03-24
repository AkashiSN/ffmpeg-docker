# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
rm -rf /var/lib/apt/lists/*
apt-get update
apt-get install -y \
    build-essential \
    clang \
    curl \
    libtool \
    make \
    mingw-w64 \
    mingw-w64-tools \
    nasm \
    pkg-config \
    yasm
EOT

# ffmpeg-library-build image
COPY --from=ghcr.io/akashisn/ffmpeg-library-build:windows / /

# Environment
ENV TARGET_OS="Windows" \
    PREFIX="/usr/local" \
    WORKDIR="/workdir"

WORKDIR ${WORKDIR}

# Copy build script
ADD *.sh ./


#
# HWAccel
#

# Build libmfx
RUN <<EOT
source ./base.sh
download_and_unpack_file "https://github.com/lu-zero/mfx_dispatch/archive/master.tar.gz" mfx_dispatch-master.tar.gz
do_configure
do_make_and_make_install
echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-libmfx" > ${PREFIX}/ffmpeg_configure_options
EOT

# Other hwaccel
RUN echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-d3d11va --enable-dxva2" > ${PREFIX}/ffmpeg_configure_options


#
# Build ffmpeg
#
ARG FFMPEG_VERSION=5.0
ENV FFMPEG_VERSION="${FFMPEG_VERSION}"

# Copy build script
ADD *.sh ./

# Run build
RUN bash ./build-ffmpeg.sh

# Copy artifacts
RUN <<EOT
mkdir /build
cp ${PREFIX}/bin/ff* /build/
EOT


# Final ffmpeg image
FROM scratch AS ffmpeg

COPY --from=ffmpeg-build /build /