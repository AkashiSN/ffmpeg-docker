FROM ubuntu:20.04 AS ffmpeg-build

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && \
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
      yasm \
    && \
    pip3 install meson


ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS="" \
    \
    CFLAGS="-fPIC"


#
# Common Tools
#

# zlib
ENV ZLIB_VERSION=1.2.11
RUN curl -sL -o /tmp/zlib-${ZLIB_VERSION}.tar.xz https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf zlib-${ZLIB_VERSION}.tar.xz && \
    cd /tmp/zlib-${ZLIB_VERSION} && \
    ./configure --static && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-zlib"

# Build Nettle
ENV NETTLE_VERSION=3.7.3
RUN curl -sL -o /tmp/nettle-${NETTLE_VERSION}.tar.gz https://ftp.jaist.ac.jp/pub/GNU/nettle/nettle-${NETTLE_VERSION}.tar.gz
RUN cd /tmp && \
    tar xf /tmp/nettle-${NETTLE_VERSION}.tar.gz && \
    cd /tmp/nettle-${NETTLE_VERSION} && \
    ./configure --libdir=/usr/local/lib --enable-static --disable-shared --enable-mini-gmp && \
    make -j $(nproc) && \
    make install

# Build GMP
ENV GMP_VERSION=6.2.1
RUN curl -sL -o /tmp/gmp-${GMP_VERSION}.tar.lz https://ftp.jaist.ac.jp/pub/GNU/gmp/gmp-${GMP_VERSION}.tar.lz
RUN cd /tmp && \
    tar xf /tmp/gmp-${GMP_VERSION}.tar.lz && \
    cd /tmp/gmp-${GMP_VERSION} && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install

# Build Libtasn1
ENV LIBTASN1_VERSION=4.18.0
RUN curl -sL -o /tmp/libtasn1-${LIBTASN1_VERSION}.tar.gz https://ftp.jaist.ac.jp/pub/GNU/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz
RUN cd /tmp && \
    tar xf /tmp/libtasn1-${LIBTASN1_VERSION}.tar.gz && \
    cd /tmp/libtasn1-${LIBTASN1_VERSION} && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install

# Build libunistring
ENV LIBUNISTRING_VERSION=0.9.10
RUN curl -sL -o /tmp/libunistring-${LIBUNISTRING_VERSION}.tar.xz https://ftp.jaist.ac.jp/pub/GNU/libunistring/libunistring-${LIBUNISTRING_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf /tmp/libunistring-${LIBUNISTRING_VERSION}.tar.xz && \
    cd /tmp/libunistring-${LIBUNISTRING_VERSION} && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install

# Build GnuTLS
ENV GNUTLS_VERSION=3.6.16
RUN curl -L -o /tmp/gnutls-${GNUTLS_VERSION}.tar.xz https://mirrors.dotsrc.org/gcrypt/gnutls/v3.6/gnutls-${GNUTLS_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf /tmp/gnutls-${GNUTLS_VERSION}.tar.xz && \
    cd /tmp/gnutls-${GNUTLS_VERSION} && \
    ./configure --enable-static --disable-shared --disable-tests --without-p11-kit && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-gnutls"

# Download Cmake
ENV CMAKE_VERSION=3.21.4
RUN curl -sL -o /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz
RUN cd /tmp && \
    tar xf /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz && \
    cd /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m) && \
    mv bin/* /usr/local/bin/ && \
    mv share/* /usr/local/share/


#
# Video
#

# Build libvpx
RUN curl -sL -o /tmp/libvpx-master.tar.gz https://github.com/webmproject/libvpx/archive/master.tar.gz
RUN cd /tmp && \
    tar xf libvpx-master.tar.gz && \
    mkdir /tmp/libvpx_build && cd /tmp/libvpx_build && \
    ../libvpx-master/configure --disable-examples --disable-docs --disable-unit-tests --as=yasm && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvpx"

# Build x264
RUN curl -sL -o /tmp/x264-master.tar.bz2 https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2
RUN cd /tmp && \
    tar xf x264-master.tar.bz2 && \
    mkdir /tmp/x264_build && cd /tmp/x264_build && \
    ../x264-master/configure --enable-static --disable-cli && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx264"

# Build x265
RUN curl -sL -o /tmp/x265-master.tar.gz https://github.com/videolan/x265/archive/master.tar.gz
RUN cd /tmp && \
    tar xf x265-master.tar.gz && \
    mkdir /tmp/x265_build && cd /tmp/x265_build && \
    cmake -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 \
          ../x265-master/source && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx265" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lpthread"

# Build libaom
RUN git clone https://aomedia.googlesource.com/aom -b master --depth 1 /tmp/aom
RUN mkdir /tmp/aom_build && cd /tmp/aom_build && \
    cmake -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 \
          -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 ../aom && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaom"


#
# Audio
#

# Build opus
RUN curl -sL -o /tmp/opus-master.tar.gz https://github.com/xiph/opus/archive/master.tar.gz
RUN cd /tmp && \
    tar xf opus-master.tar.gz && \
    mkdir /tmp/opus_build && cd /tmp/opus_build && \
    cmake -DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 ../opus-master && \
    make -j $(nproc) && \
    make install && \
    rm -rf /usr/local/lib/cmake
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopus"

# Build libogg, for vorbis
RUN curl -sL -o /tmp/ogg-master.tar.gz https://github.com/xiph/ogg/archive/master.tar.gz
RUN cd /tmp && \
    tar xf ogg-master.tar.gz && \
    mkdir /tmp/ogg_build && cd /tmp/ogg_build && \
    cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DINSTALL_DOCS=0 \
          -DBUILD_TESTING=0 ../ogg-master && \
    make -j $(nproc) && \
    make install

# Build vorbis
RUN curl -sL -o /tmp/vorbis-master.tar.gz https://github.com/xiph/vorbis/archive/master.tar.gz
RUN cd /tmp && \
    tar xf vorbis-master.tar.gz && \
    mkdir /tmp/vorbis_build && cd /tmp/vorbis_build && \
    cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DBUILD_TESTING=0 \
          ../vorbis-master && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvorbis"


#
# Caption
#

# Build freetype
RUN curl -sL -o /tmp/freetype-master.tar.bz2  https://gitlab.freedesktop.org/freetype/freetype/-/archive/master/freetype-master.tar.bz2
RUN cd /tmp && \
    tar xf freetype-master.tar.bz2 && \
    mkdir /tmp/freetype_build && cd /tmp/freetype_build && \
    cmake -DBUILD_SHARED_LIBS=0 ../freetype-master && \
    make -j $(nproc) && \
    make install  && \
    rm -rf /usr/local/lib/cmake
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfreetype"

# Build fribidi
RUN curl -sL -o /tmp/fribidi-master.tar.gz https://github.com/fribidi/fribidi/archive/master.tar.gz
RUN cd /tmp && \
    tar xf fribidi-master.tar.gz && \
    cd /tmp/fribidi-master && \
    meson setup -Ddocs=false -Dtests=false -Dbin=false -Ddefault_library=static -Dlibdir=/usr/local/lib/ ./build && \
    ninja -v -C ./build && \
    cd build && \
    meson install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfribidi"

# Build libexpat
RUN curl -sL -o /tmp/libexpat-master.tar.gz https://github.com/libexpat/libexpat/archive/master.tar.gz
RUN cd /tmp && \
    tar xf /tmp/libexpat-master.tar.gz && \
    mkdir /tmp/libexpat_build && cd /tmp/libexpat_build && \
    cmake -DEXPAT_BUILD_TOOLS=0 -DEXPAT_BUILD_EXAMPLES=0 -DEXPAT_BUILD_TESTS=0 -DEXPAT_SHARED_LIBS=0 \
          -DEXPAT_BUILD_DOCS=0 ../libexpat-master/expat/ && \
    make -j $(nproc) && \
    make install && \
    rm -rf /usr/local/lib/cmake

# Build fontconfig
RUN curl -sL -o /tmp/fontconfig-main.tar.bz2  https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/main/fontconfig-main.tar.bz2
RUN cd /tmp && \
    tar xf fontconfig-main.tar.bz2 && \
    cd /tmp/fontconfig-main && \
    meson setup -Ddoc=disabled -Dtests=disabled -Dtools=disabled -Ddefault_library=static -Dlibdir=/usr/local/lib/ ./build && \
    ninja -v -C ./build && \
    cd build && \
    meson install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfontconfig"

# Build libharfbuzz
RUN curl -sL -o /tmp/harfbuzz-main.tar.gz https://github.com/harfbuzz/harfbuzz/archive/main.tar.gz
RUN cd /tmp && \
    tar xf harfbuzz-main.tar.gz && \
    cd /tmp/harfbuzz-main && \
    meson setup -Ddocs=disabled -Dtests=disabled -Ddefault_library=static -Dlibdir=/usr/local/lib/ ./build && \
    ninja -v -C ./build && \
    cd build && \
    meson install && \
    rm -rf /usr/local/lib/cmake

# Build libass
RUN curl -sL -o /tmp/libass-master.tar.gz https://github.com/libass/libass/archive/master.tar.gz
RUN cd /tmp && \
    tar xf libass-master.tar.gz && \
    cd /tmp/libass-master && \
    ./autogen.sh && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libass"

# Build libpng
ENV LIBPNG_VERSION=1.6.37
RUN curl -sL -o /tmp/libpng-${LIBPNG_VERSION}.tar.xz https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf libpng-${LIBPNG_VERSION}.tar.xz && \
    mkdir /tmp/libpng_build && cd /tmp/libpng_build && \
    cmake -DPNG_SHARED=0 -DPNG_STATIC=1 -DPNG_TESTS=0 ../libpng-${LIBPNG_VERSION} && \
    make -j $(nproc) && \
    make install && \
    rm -rf /usr/local/lib/libpng

# Build libaribb24
RUN curl -sL -o /tmp/aribb24-master.tar.bz2 https://salsa.debian.org/multimedia-team/aribb24/-/archive/master/aribb24-master.tar.bz2
RUN cd /tmp && \
    tar xf aribb24-master.tar.bz2 && \
    cd /tmp/aribb24-master && \
    ./bootstrap && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaribb24"


#
# Copy artifacts
#
RUN mkdir /build && \
    cp --archive --parents --no-dereference /usr/local/lib /build && \
    cp --archive --parents --no-dereference /usr/local/include /build && \
    echo $FFMPEG_CONFIGURE_OPTIONS > /build/usr/local/ffmpeg_configure_options && \
    echo $FFMPEG_EXTRA_LIBS > /build/usr/local/ffmpeg_extra_libs


# final image
FROM scratch

COPY --from=ffmpeg-build /build /