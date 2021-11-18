# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
apt-get update
apt-get install -y \
    build-essential \
    clang \
    curl \
    git \
    libtool \
    make \
    mingw-w64 \
    mingw-w64-tools \
    nasm \
    pkg-config \
    yasm
EOT

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS="" \
    \
    HOST_TARGET="x86_64-w64-mingw32" \
    LIB_PREFIX="/usr/x86_64-w64-mingw32" \
    CROSS_PREFIX="x86_64-w64-mingw32-" \
    \
    PKG_CONFIG_PATH="/usr/x86_64-w64-mingw32/lib/pkgconfig" \
    CPPFLAGS="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0" \
    CFLAGS="-mtune=generic -O3"


#
# Common Tools
#

# Build zlib
ENV ZLIB_VERSION=1.2.11
RUN curl -sL -o /tmp/zlib-${ZLIB_VERSION}.tar.xz https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/zlib-${ZLIB_VERSION}.tar.xz -C /tmp
cd /tmp/zlib-${ZLIB_VERSION}
CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib ./configure --prefix=${LIB_PREFIX} --static
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-zlib"

# Download Cmake
ENV CMAKE_VERSION=3.21.4
RUN curl -sL -o /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz
RUN <<EOT
tar xf /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz -C /tmp
cd /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m)
mv bin/* /usr/local/bin/
mv share/* /usr/local/share/
EOT


#
# Video
#

# Build libvpx
ADD https://github.com/webmproject/libvpx/archive/master.tar.gz /tmp/libvpx-master.tar.gz
RUN <<EOT
tar xf /tmp/libvpx-master.tar.gz -C /tmp
mkdir /tmp/libvpx_build && cd /tmp/libvpx_build
CROSS=${CROSS_PREFIX} ../libvpx-master/configure --disable-examples --disable-docs --disable-unit-tests \
                                                 --target=x86_64-win64-gcc --prefix=${LIB_PREFIX}
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvpx" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lpthread"

# Build x264
ADD https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/x264-master.tar.bz2 -C /tmp
mkdir /tmp/x264_build && cd /tmp/x264_build
../x264-master/configure --enable-static --disable-cli --host=${HOST_TARGET} --prefix=${LIB_PREFIX} \
                         --cross-prefix=${CROSS_PREFIX}
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx264"

# Build x265
ENV X265_VERSION=3.5
RUN git clone https://bitbucket.org/multicoreware/x265_git -b ${X265_VERSION} --depth 1 /tmp/x265
COPY <<'EOT' /tmp/x265_build/cross.cmake
SET(CMAKE_SYSTEM_NAME Windows)
SET(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
SET(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
SET(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
SET(CMAKE_ASM_YASM_COMPILER yasm)
SET(CMAKE_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
EOT

RUN <<EOT
cd /tmp/x265_build
mkdir -p 8bit 10bit 12bit
\
cd 12bit
cmake -DCMAKE_TOOLCHAIN_FILE=../cross.cmake -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF \
      -DENABLE_CLI=OFF -DMAIN12=ON ../../x265/source
make -j $(nproc)
cp libx265.a ../8bit/libx265_main12.a
\
cd ../10bit
cmake -DCMAKE_TOOLCHAIN_FILE=../cross.cmake -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF \
      -DENABLE_CLI=OFF ../../x265/source
make -j $(nproc)
cp libx265.a ../8bit/libx265_main10.a
\
cd ../8bit
cmake -DCMAKE_TOOLCHAIN_FILE=../cross.cmake -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. \
      -DLINKED_10BIT=ON -DLINKED_12BIT=ON -DCMAKE_INSTALL_PREFIX=${LIB_PREFIX} ../../x265/source
make -j $(nproc)
\
mv libx265.a libx265_main.a
\
ar -M <<EOS
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOS
\
make install
\
rm /usr/x86_64-w64-mingw32/lib/libx265.dll.a
EOT

ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx265" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lm -lz -lstdc++"

# Build libaom
RUN git clone https://aomedia.googlesource.com/aom -b master --depth 1 /tmp/aom
RUN <<EOT
mkdir /tmp/aom_build && cd /tmp/aom_build
cmake -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 \
      -DCMAKE_TOOLCHAIN_FILE=../aom/build/cmake/toolchains/x86_64-mingw-gcc.cmake -DAOM_TARGET_CPU=x86_64 \
      -DCMAKE_INSTALL_PREFIX=${LIB_PREFIX} ../aom
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaom"


#
# Audio
#

# Build opus
ADD https://github.com/xiph/opus/archive/master.tar.gz /tmp/opus-master.tar.gz
COPY <<'EOT' /tmp/cross.cmake
SET(CMAKE_SYSTEM_NAME Windows)
SET(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
SET(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
SET(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
EOT
RUN <<EOT
tar xf /tmp/opus-master.tar.gz -C /tmp
mkdir /tmp/opus_build && cd /tmp/opus_build
cmake -DCMAKE_TOOLCHAIN_FILE=../cross.cmake -DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 \
      -DOPUS_STACK_PROTECTOR=0 -DOPUS_FORTIFY_SOURCE=0 -DCMAKE_INSTALL_PREFIX=${LIB_PREFIX} ../opus-master
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopus"

# Build libogg, for vorbis
ADD https://github.com/xiph/ogg/archive/master.tar.gz /tmp/ogg-master.tar.gz
RUN <<EOT
tar xf /tmp/ogg-master.tar.gz -C /tmp
mkdir /tmp/ogg_build && cd /tmp/ogg_build
cmake -DCMAKE_TOOLCHAIN_FILE=../cross.cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 \
      -DINSTALL_DOCS=0 -DBUILD_TESTING=0 -DCMAKE_INSTALL_PREFIX=${LIB_PREFIX} ../ogg-master
make -j $(nproc)
make install
EOT

# Build vorbis
ADD https://github.com/xiph/vorbis/archive/master.tar.gz /tmp/vorbis-master.tar.gz
RUN <<EOT
tar xf /tmp/vorbis-master.tar.gz -C /tmp
mkdir /tmp/vorbis_build && cd /tmp/vorbis_build
cmake -DCMAKE_TOOLCHAIN_FILE=../cross.cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 \
      -DBUILD_TESTING=0 -DCMAKE_INSTALL_PREFIX=${LIB_PREFIX} ../vorbis-master
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvorbis"


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
./configure --enable-static --disable-shared --host=${HOST_TARGET} --prefix=${LIB_PREFIX}
make -j$(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libmfx" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lsupc++"

# Build NVcodec
ADD https://github.com/FFmpeg/nv-codec-headers/archive/master.tar.gz /tmp/nv-codec-headers-master.tar.gz
RUN <<EOT
tar xf /tmp/nv-codec-headers-master.tar.gz -C /tmp
cd /tmp/nv-codec-headers-master
make install "PREFIX=${LIB_PREFIX}"
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-cuda-llvm --enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc"

# Other hwaccel
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-d3d11va --enable-dxva2"


# Remove dynamic dll
RUN <<EOT
rm /usr/x86_64-w64-mingw32/lib/libpthread.dll.a
rm /usr/lib/gcc/x86_64-w64-mingw32/9.3-win32/libstdc++.dll.a
EOT

#
# Build ffmpeg
#
ARG FFMPEG_VERSION=4.4.1
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz -C /tmp
cd /tmp/ffmpeg-${FFMPEG_VERSION}
./configure ${FFMPEG_CONFIGURE_OPTIONS} \
            --arch=x86_64 \
            --cross-prefix=${CROSS_PREFIX} \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --disable-ffplay \
            --disable-w32threads \
            --enable-cross-compile \
            --enable-gpl \
            --enable-version3 \
            --extra-libs="${FFMPEG_EXTRA_LIBS}" \
            --target-os=mingw64 \
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


# export ffmpeg image
FROM scratch AS ffmpeg

COPY --from=ffmpeg-build /build /