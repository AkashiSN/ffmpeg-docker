# syntax = docker/dockerfile:1.5

ARG FFMPEG_VERSION="7.0.2"
ARG TARGET_OS="linux"
ARG CUDA_SDK_VERSION="12.2.0"
FROM ghcr.io/akashisn/ffmpeg-library:${TARGET_OS} AS ffmpeg-library

#
# cuda build env base image
#
FROM nvidia/cuda:${CUDA_SDK_VERSION}-devel-ubuntu22.04 AS cuda-build-env

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

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

# ffmpeg-library image
COPY --from=ffmpeg-library / /

# Environment
ARG FFMPEG_VERSION
ENV FFMPEG_VERSION="${FFMPEG_VERSION}" \
    PREFIX="/usr/local" \
    LDFLAGS="-L${PREFIX}/cuda/lib64" \
    CFLAGS="-I${PREFIX}/cuda/include" \
    ARTIFACT_DIR="/dist" \
    RUNTIME_LIB_DIR="/runtime" \
    WORKDIR="/workdir"
WORKDIR ${WORKDIR}

# Copy build script
ADD ./scripts/*.sh ./

#
# ffmpeg build stage
#
FROM cuda-build-env AS ffmpeg-build


#
# Audio
#

# Build fdk-aac
ENV FDK_AAC_VERSION=2.0.2
RUN <<EOT
source ./base.sh
git_clone "https://github.com/mstorsjo/fdk-aac.git"
do_configure "--enable-static --disable-shared"
do_make_and_make_install
sed -i -e 's/$/ --enable-libfdk-aac/g' ${PREFIX}/ffmpeg_configure_options
EOT


#
# HWAccel
#

# cuda-nvcc and libnpp
ARG CUDA_SDK_VERSION
# ARG NVIDIA_DRIVER_VERSION=511.23
# ADD ./cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_windows.exe /tmp/cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_windows.exe
RUN <<EOT
if [ "${TARGET_OS}" = "Windows" ]; then
    mkdir /tmp/cuda && cd /tmp/cuda
    7zr x /tmp/cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_windows.exe
    rm /usr/local/cuda/include/npp*
    rm /usr/local/cuda/lib64/libnpp*
    cp -r libnpp/npp_dev/include ${PREFIX}
    cp libnpp/npp_dev/lib/x64/* ${PREFIX}/lib/
    sed -i -e 's/$/ --enable-cuda-nvcc --enable-libnpp/g' ${PREFIX}/ffmpeg_configure_options
else
    sed -i -e 's/$/ --enable-cuda-nvcc --enable-libnpp/g' ${PREFIX}/ffmpeg_configure_options
fi
    sed -i -e 's/$/ --nvccflags="-gencode arch=compute_52,code=sm_52"/g' ${PREFIX}/ffmpeg_configure_options
EOT


#
# Build ffmpeg
#

# Run build
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


# Copy artifacts
RUN <<EOT
mkdir /build
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    cp ${PREFIX}/bin/ff* /build/
    cp /tmp/cuda/libnpp/npp/bin/*.dll /build/
else
    cp --archive --parents --no-dereference ${PREFIX}/run.sh /build
    cp --archive --parents --no-dereference ${PREFIX}/bin/ff* /build
    cp --archive --parents --no-dereference ${PREFIX}/configure_options /build
    cp --archive --parents --no-dereference ${PREFIX}/lib/*.so* /build
    cd /usr/local/cuda/targets/x86_64-linux/lib
    cp libnppig* /build/lib
    cp libnppicc* /build/lib
    cp libnppidei* /build/lib
    cp libnppc* /build/lib
    rm /build/lib/libva-glx.so*
    rm /build/lib/libva-x11.so*
fi
EOT


# Final ffmpeg image
FROM scratch AS ffmpeg

COPY --from=ffmpeg-build /dist /
