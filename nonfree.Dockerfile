# syntax = docker/dockerfile:1.3-labs

ARG TARGET_OS="linux"
ARG CUDA_SDK_VERSION=11.6.0

FROM ghcr.io/akashisn/ffmpeg-library-build:${TARGET_OS} AS ffmpeg-library-build

FROM nvidia/cuda:${CUDA_SDK_VERSION}-devel-ubuntu20.04 AS ffmpeg-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

# Install build tools
RUN <<EOT
rm -rf /var/lib/apt/lists/*
sed -i -r 's!(deb|deb-src) \S+!\1 http://jp.archive.ubuntu.com/ubuntu/!' /etc/apt/sources.list
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
    p7zip \
    pkg-config \
    yasm
EOT

# ffmpeg-library-build image
COPY --from=ffmpeg-library-build / /

ENV TARGET_OS=${TARGET_OS} \
    PREFIX="/usr/local" \
    LDFLAGS="-L${PREFIX}/cuda/lib64" \
    CFLAGS="-I${PREFIX}/cuda/include" \
    WORKDIR="/workdir"

WORKDIR ${WORKDIR}

# Copy build script
ADD ./scripts/*.sh ./


#
# Audio
#

# Build fdk-aac
ENV FDK_AAC_VERSION=2.0.2
RUN <<EOT
source ./base.sh
download_and_unpack_file "https://download.sourceforge.net/opencore-amr/fdk-aac/fdk-aac-${FDK_AAC_VERSION}.tar.gz"
do_configure
do_make_and_make_install
echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-libfdk-aac" > ${PREFIX}/ffmpeg_configure_options
EOT


#
# HWAccel
#

# cuda-nvcc and libnpp
ARG CUDA_SDK_VERSION
ARG NVIDIA_DRIVER_VERSION=511.23
ADD ./cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_windows.exe /tmp/cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_windows.exe
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    mkdir /tmp/cuda && cd /tmp/cuda
    7zr x /tmp/cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_windows.exe
    rm /usr/local/cuda/include/npp*
    rm /usr/local/cuda/lib64/libnpp*
    cp -r libnpp/npp_dev/include ${PREFIX}
    cp libnpp/npp_dev/lib/x64/* ${PREFIX}/lib/
    echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-cuda-nvcc" > ${PREFIX}/ffmpeg_configure_options
else
    echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-cuda-nvcc --enable-libnpp" > ${PREFIX}/ffmpeg_configure_options
fi
echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --nvccflags='-gencode arch=compute_52,code=sm_52'" > ${PREFIX}/ffmpeg_configure_options
EOT

# Build libmfx
ADD https://github.com/lu-zero/mfx_dispatch/archive/master.tar.gz /tmp/mfx_dispatch-master.tar.gz
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    source ./base.sh
    download_and_unpack_file "https://github.com/lu-zero/mfx_dispatch/archive/master.tar.gz"
    do_configure
    do_make_and_make_install
    echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-libmfx" > ${PREFIX}/ffmpeg_configure_options
fi
EOT

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.3.5
RUN <<EOT
if [ "${HOST_TARGET}" != "x86_64-w64-mingw32" ]; then
    apt-get install -y libdrm2 libxext6 libxfixes3
    source ./base.sh
    download_and_unpack_file "https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz"
    cd opt/intel/mediasdk
    cp --archive --no-dereference include ${PREFIX}/
    cp --archive --no-dereference lib64/. ${PREFIX}/lib/
    ldconfig
    echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-libmfx --enable-vaapi" > ${PREFIX}/ffmpeg_configure_options
fi
EOT


# Other hwaccel
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-d3d11va --enable-dxva2" > ${PREFIX}/ffmpeg_configure_options
fi
EOT

# Remove dynamic dll
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    rm /usr/x86_64-w64-mingw32/lib/libpthread.dll.a
    rm /usr/lib/gcc/x86_64-w64-mingw32/*/libstdc++.dll.a
fi
EOT

# Other hwaccel
RUN echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-d3d11va --enable-dxva2" > ${PREFIX}/ffmpeg_configure_options


#
# Build ffmpeg
#
ARG FFMPEG_VERSION=5.0.1
ENV FFMPEG_VERSION="${FFMPEG_VERSION}"

# Run build
RUN bash ./build-ffmpeg.sh

# Copy artifacts
RUN <<EOT
mkdir /build
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    cp ${PREFIX}/bin/ff* /build/
    cp /tmp/cuda/libnpp/npp/bin/*.dll /build/
else
    cat <<'EOS' > ${PREFIX}/run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib
export LIBVA_DRIVER_NAME=iHD
exec $@
EOS
    chmod +x ${PREFIX}/run.sh
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

COPY --from=ffmpeg-build /build /
