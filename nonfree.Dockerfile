# syntax = docker/dockerfile:1.3-labs

ARG TARGET_OS="linux"
ARG CUDA_SDK_VERSION=11.6.0

FROM ghcr.io/akashisn/ffmpeg-library-build:${TARGET_OS} AS ffmpeg-library

FROM nvidia/cuda:${CUDA_SDK_VERSION}-devel-ubuntu20.04 AS ffmpeg-build

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

# Install build tools
RUN <<EOT
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

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""
ARG HOST_TARGET=
ENV CROSS_PREFIX="${HOST_TARGET:+$HOST_TARGET-}" \
    LIBRARY_PREFIX="/usr/local"
ENV PKG_CONFIG="pkg-config" \
    LD_LIBRARY_PATH="${LIBRARY_PREFIX}/lib" \
    PKG_CONFIG_PATH="${LIBRARY_PREFIX}/lib/pkgconfig" \
    LDFLAGS="-L${LIBRARY_PREFIX}/lib -L${LIBRARY_PREFIX}/cuda/lib64" \
    CFLAGS="-I${LIBRARY_PREFIX}/include -I${LIBRARY_PREFIX}/cuda/include" \
    CXXFLAGS="-I${LIBRARY_PREFIX}/include"

# ffmpeg-library-build image
COPY --from=ffmpeg-library / /


#
# Audio
#

# Build fdk-aac
ENV FDK_AAC_VERSION=2.0.2
RUN curl -sL -o /tmp/fdk-aac-${FDK_AAC_VERSION}.tar.gz https://download.sourceforge.net/opencore-amr/fdk-aac/fdk-aac-${FDK_AAC_VERSION}.tar.gz
RUN <<EOT
tar xf /tmp/fdk-aac-${FDK_AAC_VERSION}.tar.gz -C /tmp
cd /tmp/fdk-aac-${FDK_AAC_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j$(nproc)
make install
echo ${HOST_TARGET} > /hoge
echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libfdk-aac" > /usr/local/ffmpeg_configure_options
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
    cp -r libnpp/npp_dev/include /usr/local
    cp libnpp/npp_dev/lib/x64/* /usr/local/lib/
    echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-cuda-nvcc --enable-libnpp" > /usr/local/ffmpeg_configure_options
else
    echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-cuda-nvcc --enable-libnpp" > /usr/local/ffmpeg_configure_options
fi
EOT

# Build libmfx
ADD https://github.com/lu-zero/mfx_dispatch/archive/master.tar.gz /tmp/mfx_dispatch-master.tar.gz
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    tar xf /tmp/mfx_dispatch-master.tar.gz -C /tmp
    cd /tmp/mfx_dispatch-master
    autoreconf -fiv
    automake --add-missing
    ./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
    make -j$(nproc)
    make install
    echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libmfx" > /usr/local/ffmpeg_configure_options
fi
EOT

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.3.5
RUN <<EOT
if [ "${HOST_TARGET}" != "x86_64-w64-mingw32" ]; then
    apt-get install -y libdrm2 libxext6 libxfixes3
    curl -sL -o /tmp/MediaStack.tar.gz https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz
    tar xf /tmp/MediaStack.tar.gz -C /tmp
    cd /tmp/MediaStack/opt/intel/mediasdk
    cp --archive --no-dereference include /usr/local/
    cp --archive --no-dereference lib64/. /usr/local/lib/
    ldconfig
    echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libmfx --enable-vaapi" > /usr/local/ffmpeg_configure_options
fi
EOT


# Other hwaccel
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-d3d11va --enable-dxva2" > /usr/local/ffmpeg_configure_options
fi
EOT

# Remove dynamic dll
RUN <<EOT
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    rm /usr/x86_64-w64-mingw32/lib/libpthread.dll.a
    rm /usr/lib/gcc/x86_64-w64-mingw32/*/libstdc++.dll.a
fi
EOT


#
# Build ffmpeg
#
ARG FFMPEG_VERSION=5.0
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz -C /tmp
cd /tmp/ffmpeg-${FFMPEG_VERSION}
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    ./configure `cat /usr/local/ffmpeg_configure_options` \
            --arch=x86_64 \
            --cross-prefix="x86_64-w64-mingw32-" \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --disable-w32threads \
            --enable-cross-compile \
            --enable-gpl \
            --enable-nonfree \
            --enable-version3 \
            --extra-libs="`cat /usr/local/ffmpeg_extra_libs`" \
            --nvccflags="-gencode arch=compute_52,code=sm_52" \
            --target-os=mingw64 \
            --pkg-config="pkg-config" \
            --pkg-config-flags="--static" > /usr/local/configure_options
else
    ./configure `cat /usr/local/ffmpeg_configure_options` \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --enable-gpl \
            --enable-nonfree \
            --enable-version3 \
            --extra-libs="`cat /usr/local/ffmpeg_extra_libs`" \
            --nvccflags="-gencode arch=compute_52,code=sm_52" \
            --pkg-config-flags="--static" > /usr/local/configure_options
fi
make -j $(nproc)
make install
EOT

# Copy artifacts
RUN <<EOT
mkdir /build
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
    cp /usr/local/bin/ff* /build/
    cp /tmp/cuda/libnpp/npp/bin/*.dll /build/
else
    cat <<'EOS' > /usr/local/run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib
export LIBVA_DRIVER_NAME=iHD
exec $@
EOS
    cd /usr/local
    chmod +x ./run.sh
    cp --archive --parents --no-dereference ./run.sh /build/
    cp --archive --parents --no-dereference ./bin/ff* /build
    cp --archive --parents --no-dereference ./configure_options /build
    cp --archive --parents --no-dereference ./lib/*.so* /build
    cd /usr/local/cuda/targets/x86_64-linux/lib
    cp --archive --parents --no-dereference libnppig* /build/lib
    cp --archive --parents --no-dereference libnppicc* /build/lib
    cp --archive --parents --no-dereference libnppidei* /build/lib
    cp --archive --parents --no-dereference libnppc* /build/lib
    rm /build/lib/libva-glx.so*
    rm /build/lib/libva-x11.so*
fi
EOT


# Final ffmpeg image
FROM scratch AS ffmpeg

COPY --from=ffmpeg-build /build /
