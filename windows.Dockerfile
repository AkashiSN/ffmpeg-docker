# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
sed -i -r 's!(deb|deb-src) \S+!\1 http://ftp.jaist.ac.jp/pub/Linux/ubuntu/!' /etc/apt/sources.list
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

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""
ENV HOST_TARGET="x86_64-w64-mingw32" \
    CROSS_PREFIX="x86_64-w64-mingw32-" \
    LIBRARY_PREFIX="/usr/local"
ENV PKG_CONFIG="pkg-config" \
    LD_LIBRARY_PATH="${LIBRARY_PREFIX}/lib" \
    PKG_CONFIG_PATH="${LIBRARY_PREFIX}/lib/pkgconfig" \
    LDFLAGS="-L${LIBRARY_PREFIX}/lib" \
    CFLAGS="-I${LIBRARY_PREFIX}/include" \
    CXXFLAGS="-I${LIBRARY_PREFIX}/include"


# ffmpeg-library-build image
COPY --from=ghcr.io/akashisn/ffmpeg-library-build:windows / /


#
# HWAccel
#

# Build libmfx
ADD https://github.com/lu-zero/mfx_dispatch/archive/master.tar.gz /tmp/mfx_dispatch-master.tar.gz
RUN <<EOT
tar xf /tmp/mfx_dispatch-master.tar.gz -C /tmp
cd /tmp/mfx_dispatch-master
autoreconf -fiv
automake --add-missing
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j$(nproc)
make install
echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libmfx" > /usr/local/ffmpeg_configure_options
EOT

# Other hwaccel
RUN echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-d3d11va --enable-dxva2" > /usr/local/ffmpeg_configure_options


#
# Build ffmpeg
#
ARG FFMPEG_VERSION=5.0
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz -C /tmp
cd /tmp/ffmpeg-${FFMPEG_VERSION}
./configure `cat /usr/local/ffmpeg_configure_options` \
            --arch="x86_64" \
            --cross-prefix="${CROSS_PREFIX}" \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --disable-w32threads \
            --enable-cross-compile \
            --enable-gpl \
            --enable-version3 \
            --extra-libs="-static -static-libgcc -static-libstdc++ -Wl,-Bstatic `cat /usr/local/ffmpeg_extra_libs`" \
            --extra-cflags="--static" \
            --target-os="mingw64" \
            --pkg-config="pkg-config" \
            --pkg-config-flags="--static" > /usr/local/configure_options
make -j $(nproc)
make install
EOT

# Copy artifacts
RUN <<EOT
mkdir /build
cp /usr/local/bin/ff* /build/
EOT


# Final ffmpeg image
FROM scratch AS ffmpeg

COPY --from=ffmpeg-build /build /