# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
apt-get update
apt-get install -y \
    autoconf \
    automake \
    autopoint \
    build-essential \
    curl \
    gettext \
    git \
    gperf \
    libtool \
    lzip \
    make \
    nasm \
    ninja-build \
    pkg-config \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    yasm
pip3 install meson
EOT


ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""


#
# Common Tools
#

# zlib
ENV ZLIB_VERSION=1.2.11
RUN curl -sL -o /tmp/zlib-${ZLIB_VERSION}.tar.xz https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/zlib-${ZLIB_VERSION}.tar.xz -C /tmp
cd /tmp/zlib-${ZLIB_VERSION}
./configure --static
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-zlib"

# Build Nettle
ENV NETTLE_VERSION=3.7.3
ADD https://ftp.jaist.ac.jp/pub/GNU/nettle/nettle-${NETTLE_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/nettle-${NETTLE_VERSION}.tar.gz -C /tmp
cd /tmp/nettle-${NETTLE_VERSION}
CCPIC=-fPIC ./configure --libdir=/usr/local/lib --enable-static --disable-shared --enable-mini-gmp
make -j $(nproc)
make install
EOT

# Build GMP
ENV GMP_VERSION=6.2.1
ADD  https://ftp.jaist.ac.jp/pub/GNU/gmp/gmp-${GMP_VERSION}.tar.lz /tmp/
RUN <<EOT
tar xf /tmp/gmp-${GMP_VERSION}.tar.lz -C /tmp
cd /tmp/gmp-${GMP_VERSION}
./configure --enable-static --disable-shared
make -j $(nproc)
make install
EOT

# Build Libtasn1
ENV LIBTASN1_VERSION=4.18.0
ADD https://ftp.jaist.ac.jp/pub/GNU/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/libtasn1-${LIBTASN1_VERSION}.tar.gz -C /tmp
cd /tmp/libtasn1-${LIBTASN1_VERSION}
./configure --enable-static --disable-shared
make -j $(nproc)
make install
EOT

# Build libunistring
ENV LIBUNISTRING_VERSION=0.9.10
ADD https://ftp.jaist.ac.jp/pub/GNU/libunistring/libunistring-${LIBUNISTRING_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/libunistring-${LIBUNISTRING_VERSION}.tar.xz -C /tmp
cd /tmp/libunistring-${LIBUNISTRING_VERSION}
./configure --enable-static --disable-shared
make -j $(nproc)
make install
EOT

# Build GnuTLS
ENV GNUTLS_VERSION=3.6.16
ADD https://mirrors.dotsrc.org/gcrypt/gnutls/v3.6/gnutls-${GNUTLS_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/gnutls-${GNUTLS_VERSION}.tar.xz -C /tmp
cd /tmp/gnutls-${GNUTLS_VERSION}
./configure --enable-static --disable-shared --disable-tests --without-p11-kit
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-gnutls"

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
../libvpx-master/configure --disable-examples --disable-docs --disable-unit-tests --as=yasm
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvpx"

# Build x264
ADD https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/x264-master.tar.bz2 -C /tmp
mkdir /tmp/x264_build && cd /tmp/x264_build
../x264-master/configure --enable-static --disable-cli
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx264"

# Build x265
ENV X265_VERSION=3.5
RUN git clone https://bitbucket.org/multicoreware/x265_git -b ${X265_VERSION} --depth 1 /tmp/x265
RUN <<EOT
mkdir /tmp/x265_build && cd /tmp/x265_build
mkdir -p 8bit 10bit 12bit
\
cd 12bit
cmake -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DMAIN12=ON ../../x265/source
make -j $(nproc)
cp libx265.a ../8bit/libx265_main12.a
\
cd ../10bit
cmake -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF ../../x265/source
make -j $(nproc)
cp libx265.a ../8bit/libx265_main10.a
\
cd ../8bit
cmake -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON ../../x265/source
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
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx265" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lpthread"

# Build libaom
RUN git clone https://aomedia.googlesource.com/aom -b master --depth 1 /tmp/aom
RUN <<EOT
mkdir /tmp/aom_build && cd /tmp/aom_build
cmake -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 ../aom
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaom"


#
# Audio
#

# Build opus
ADD https://github.com/xiph/opus/archive/master.tar.gz /tmp/opus-master.tar.gz
RUN <<EOT
tar xf /tmp/opus-master.tar.gz -C /tmp
mkdir /tmp/opus_build && cd /tmp/opus_build
cmake -DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 ../opus-master
make -j $(nproc)
make install
rm -rf /usr/local/lib/cmake
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopus"

# Build libogg, for vorbis
ADD https://github.com/xiph/ogg/archive/master.tar.gz /tmp/ogg-master.tar.gz
RUN <<EOT
tar xf /tmp/ogg-master.tar.gz -C /tmp
mkdir /tmp/ogg_build && cd /tmp/ogg_build
cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DINSTALL_DOCS=0 -DBUILD_TESTING=0 ../ogg-master
make -j $(nproc)
make install
EOT

# Build vorbis
ADD https://github.com/xiph/vorbis/archive/master.tar.gz /tmp/vorbis-master.tar.gz
RUN <<EOT
tar xf /tmp/vorbis-master.tar.gz -C /tmp
mkdir /tmp/vorbis_build && cd /tmp/vorbis_build
cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DBUILD_TESTING=0 ../vorbis-master
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvorbis"


#
# Caption
#

# Build freetype
ADD https://gitlab.freedesktop.org/freetype/freetype/-/archive/master/freetype-master.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/freetype-master.tar.bz2 -C /tmp
mkdir /tmp/freetype_build && cd /tmp/freetype_build
cmake -DBUILD_SHARED_LIBS=0 ../freetype-master
make -j $(nproc)
make install
rm -rf /usr/local/lib/cmake
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfreetype"

# Build fribidi
ADD https://github.com/fribidi/fribidi/archive/master.tar.gz /tmp/fribidi-master.tar.gz
RUN <<EOT
tar xf /tmp/fribidi-master.tar.gz -C /tmp
cd /tmp/fribidi-master
meson setup -Ddocs=false -Dtests=false -Dbin=false -Ddefault_library=static -Dlibdir=/usr/local/lib/ ./build
ninja -v -C ./build
cd build
meson install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfribidi"

# Build libexpat
ADD https://github.com/libexpat/libexpat/archive/master.tar.gz /tmp/libexpat-master.tar.gz
RUN <<EOT
tar xf /tmp/libexpat-master.tar.gz -C /tmp
mkdir /tmp/libexpat_build && cd /tmp/libexpat_build
cmake -DEXPAT_BUILD_TOOLS=0 -DEXPAT_BUILD_EXAMPLES=0 -DEXPAT_BUILD_TESTS=0 -DEXPAT_SHARED_LIBS=0 -DEXPAT_BUILD_DOCS=0 ../libexpat-master/expat/
make -j $(nproc)
make install
rm -rf /usr/local/lib/cmake
EOT

# Build fontconfig
ADD https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/main/fontconfig-main.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/fontconfig-main.tar.bz2 -C /tmp
cd /tmp/fontconfig-main
meson setup -Ddoc=disabled -Dtests=disabled -Dtools=disabled -Ddefault_library=static -Dlibdir=/usr/local/lib/ ./build
ninja -v -C ./build
cd build
meson install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfontconfig"

# Build libharfbuzz
ADD https://github.com/harfbuzz/harfbuzz/archive/main.tar.gz /tmp/harfbuzz-main.tar.gz
RUN <<EOT
tar xf /tmp/harfbuzz-main.tar.gz -C /tmp
cd /tmp/harfbuzz-main
meson setup -Ddocs=disabled -Dtests=disabled -Ddefault_library=static -Dlibdir=/usr/local/lib/ ./build
ninja -v -C ./build
cd build
meson install
rm -rf /usr/local/lib/cmake
EOT

# Build libass
ADD https://github.com/libass/libass/archive/master.tar.gz /tmp/libass-master.tar.gz
RUN <<EOT
tar xf /tmp/libass-master.tar.gz -C /tmp
cd /tmp/libass-master
./autogen.sh
./configure --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libass"

# Build libpng
ENV LIBPNG_VERSION=1.6.37
RUN curl -sL -o /tmp/libpng-${LIBPNG_VERSION}.tar.xz https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/libpng-${LIBPNG_VERSION}.tar.xz -C /tmp
mkdir /tmp/libpng_build && cd /tmp/libpng_build
cmake -DPNG_SHARED=0 -DPNG_STATIC=1 -DPNG_TESTS=0 ../libpng-${LIBPNG_VERSION}
make -j $(nproc)
make install
rm -rf /usr/local/lib/libpng
EOT

# Build libaribb24
ADD https://salsa.debian.org/multimedia-team/aribb24/-/archive/master/aribb24-master.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/aribb24-master.tar.bz2 -C /tmp
cd /tmp/aribb24-master
./bootstrap
./configure --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaribb24"


#
# Copy artifacts
#
RUN <<EOT
mkdir /build
cp --archive --parents --no-dereference /usr/local/lib /build
cp --archive --parents --no-dereference /usr/local/include /build
echo $FFMPEG_CONFIGURE_OPTIONS > /build/usr/local/ffmpeg_configure_options
echo $FFMPEG_EXTRA_LIBS > /build/usr/local/ffmpeg_extra_libs
EOT


# final image
FROM scratch

COPY --from=ffmpeg-build /build /