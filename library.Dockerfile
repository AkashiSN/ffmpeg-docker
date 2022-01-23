# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-library-build

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
sed -i -r 's!(deb|deb-src) \S+!\1 http://ftp.jaist.ac.jp/pub/Linux/ubuntu/!' /etc/apt/sources.list
apt-get update
apt-get install -y \
    autopoint \
    build-essential \
    clang \
    curl \
    gettext \
    git \
    gperf \
    libtool \
    lzip \
    make \
    mingw-w64 \
    mingw-w64-tools \
    nasm \
    pkg-config \
    subversion \
    yasm
EOT

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""
ARG HOST_TARGET=
ENV CROSS_PREFIX="${HOST_TARGET:+$HOST_TARGET-}"
ENV LIBRARY_PREFIX="/usr/local"
ENV PKG_CONFIG="pkg-config" \
    LD_LIBRARY_PATH="${LIBRARY_PREFIX}/lib" \
    PKG_CONFIG_PATH="${LIBRARY_PREFIX}/lib/pkgconfig" \
    LDFLAGS="-L${LIBRARY_PREFIX}/lib" \
    CFLAGS="-I${LIBRARY_PREFIX}/include" \
    CXXFLAGS="-I${LIBRARY_PREFIX}/include"


#
# Build Tools
#

# Download Cmake
ENV CMAKE_VERSION=3.22.1
RUN curl -sL -o /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz
RUN <<EOT
tar xf /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz -C /tmp
cd /tmp/cmake-${CMAKE_VERSION}-linux-$(uname -m)
mv bin/* /usr/local/bin/
mv share/* /usr/local/share/
EOT

# Cmake build toolchain
RUN <<EOT
OS="Linux"
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
      OS="Windows"
fi
cat << EOS > /tmp/toolchains.cmake
SET(CMAKE_SYSTEM_NAME ${OS})
SET(CMAKE_C_COMPILER ${CROSS_PREFIX}gcc)
SET(CMAKE_CXX_COMPILER ${CROSS_PREFIX}g++)
SET(CMAKE_RC_COMPILER ${CROSS_PREFIX}windres)
EOS
EOT


#
# Common Tools
#

# Build zlib
ENV ZLIB_VERSION=1.2.11
RUN curl -sL -o /tmp/zlib-${ZLIB_VERSION}.tar.xz https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/zlib-${ZLIB_VERSION}.tar.xz -C /tmp
cd /tmp/zlib-${ZLIB_VERSION}
CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib ./configure --prefix=${LIBRARY_PREFIX} --static
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-zlib"

# Build libpng
ENV LIBPNG_VERSION=1.6.37
RUN curl -sL -o /tmp/libpng-${LIBPNG_VERSION}.tar.xz https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/libpng-${LIBPNG_VERSION}.tar.xz -C /tmp
mkdir /tmp/libpng_build && cd /tmp/libpng_build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DPNG_SHARED=0 -DPNG_STATIC=1 -DPNG_TESTS=0 \
      -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../libpng-${LIBPNG_VERSION}
make -j $(nproc)
make install
EOT

# Build libjpg
ENV LIBJPG_VERSION=9e
ADD http://www.ijg.org/files/jpegsrc.v${LIBJPG_VERSION}.tar.gz /tmp/jpegsrc-v${LIBJPG_VERSION}.tar.gz
RUN <<EOT
tar xf /tmp/jpegsrc-v${LIBJPG_VERSION}.tar.gz -C /tmp
cd /tmp/jpeg-${LIBJPG_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT

# Build openjpeg
ADD https://github.com/uclouvain/openjpeg/archive/master.tar.gz /tmp/openjpeg-master.tar.gz
RUN <<EOT
tar xf /tmp/openjpeg-master.tar.gz -C /tmp
mkdir /tmp/openjpeg_build && cd /tmp/openjpeg_build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DBUILD_SHARED_LIBS=0 \
      -DBUILD_TESTING=0 -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} -DBUILD_CODEC=0 ../openjpeg-master
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopenjpeg"

# Build webp
RUN git clone https://chromium.googlesource.com/webm/libwebp.git -b master --depth 1 /tmp/libwebp
RUN <<EOT
cd /tmp/libwebp
export LIBPNG_CONFIG="${LIBRARY_PREFIX}/bin/libpng-config --static"
./autogen.sh
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared --disable-wic
make -j $(nproc)
make install
unset LIBPNG_CONFIG
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libwebp"

# Build bzip2
ENV BZIP2_VERSION=1.0.8
ADD https://www.sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/bzip2-${BZIP2_VERSION}.tar.gz -C /tmp
cd /tmp/bzip2-${BZIP2_VERSION}
make CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib libbz2.a
install -m 644 bzlib.h ${LIBRARY_PREFIX}/include
install -m 644 libbz2.a ${LIBRARY_PREFIX}/lib
\
cat <<EOS > ${PKG_CONFIG_PATH}/bz2.pc
prefix=${LIBRARY_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
sharedlibdir=\${libdir}
includedir=\${prefix}/include
EOL
Name: bzip2
Description: bzip2 compression library
Version: ${BZIP2_VERSION}
EOL
Requires:
Libs: -L\${libdir} -L\${sharedlibdir}
Cflags: -I\${includedir}
EOS
sed -i.bak -e 's%EOL%\n%g' ${PKG_CONFIG_PATH}/bz2.pc
EOT

# Build lzma
ENV LZMA_VERSION=5.2.5
RUN curl -sL -o /tmp/xz-${LZMA_VERSION}.tar.xz https://sourceforge.net/projects/lzmautils/files/xz-${LZMA_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/xz-${LZMA_VERSION}.tar.xz -C /tmp
cd /tmp/xz-${LZMA_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static \
            --disable-shared --disable-xz --disable-xzdec --disable-lzmadec \
            --disable-lzmainfo --disable-scripts --disable-doc
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-lzma"

# Build Nettle
ENV NETTLE_VERSION=3.7.3
ADD https://ftp.jaist.ac.jp/pub/GNU/nettle/nettle-${NETTLE_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/nettle-${NETTLE_VERSION}.tar.gz -C /tmp
cd /tmp/nettle-${NETTLE_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --libdir=${LIBRARY_PREFIX}/lib --enable-static \
            --disable-shared --enable-mini-gmp --disable-openssl --disable-documentation
make -j $(nproc)
make install
EOT

# Build GMP
ENV GMP_VERSION=6.2.1
ADD https://ftp.jaist.ac.jp/pub/GNU/gmp/gmp-${GMP_VERSION}.tar.lz /tmp/
RUN <<EOT
tar xf /tmp/gmp-${GMP_VERSION}.tar.lz -C /tmp
cd /tmp/gmp-${GMP_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-gmp"

# Build Libtasn1
ENV LIBTASN1_VERSION=4.18.0
ADD https://ftp.jaist.ac.jp/pub/GNU/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/libtasn1-${LIBTASN1_VERSION}.tar.gz -C /tmp
cd /tmp/libtasn1-${LIBTASN1_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT

# Build libunistring
ENV LIBUNISTRING_VERSION=1.0
ADD https://ftp.jaist.ac.jp/pub/GNU/libunistring/libunistring-${LIBUNISTRING_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/libunistring-${LIBUNISTRING_VERSION}.tar.xz -C /tmp
cd /tmp/libunistring-${LIBUNISTRING_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT

# Build iconv
ENV ICONV_VERSION=1.16
ADD https://ftp.jaist.ac.jp/pub/GNU/libiconv/libiconv-${ICONV_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/libiconv-${ICONV_VERSION}.tar.gz -C /tmp
cd /tmp/libiconv-${ICONV_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make install-lib
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-iconv"

# Build GnuTLS
ENV GNUTLS_VERSION=3.7.3
ADD https://mirrors.dotsrc.org/gcrypt/gnutls/v3.7/gnutls-${GNUTLS_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/gnutls-${GNUTLS_VERSION}.tar.xz -C /tmp
cd /tmp/gnutls-${GNUTLS_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" \
      --enable-static --disable-shared --disable-tests --disable-doc --disable-tools --without-p11-kit
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-gnutls"

# Build SRT
ADD https://github.com/Haivision/srt/archive/master.tar.gz /tmp/srt-master.tar.gz
RUN <<EOT
tar xf /tmp/srt-master.tar.gz -C /tmp
mkdir /tmp/srt_build && cd /tmp/srt_build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DENABLE_SHARED=0 \
      -DBUILD_TESTING=0 -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} \
      -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include \
      -DENABLE_APPS=0 -DUSE_STATIC_LIBSTDCXX=1 -DUSE_ENCLIB=gnutls ../srt-master
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libsrt"


#
# Video
#

# Build libvpx
ADD https://github.com/webmproject/libvpx/archive/master.tar.gz /tmp/libvpx-master.tar.gz
RUN <<EOT
tar xf /tmp/libvpx-master.tar.gz -C /tmp
mkdir /tmp/libvpx_build && cd /tmp/libvpx_build
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
      CROSS=${CROSS_PREFIX} ../libvpx-master/configure --prefix=${LIBRARY_PREFIX} \
            --target=x86_64-win64-gcc --disable-examples --disable-docs --disable-unit-tests --as=yasm
else
      ../libvpx-master/configure --disable-examples --disable-docs --disable-unit-tests --as=yasm
fi
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvpx"

# Build x264
ADD https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/x264-master.tar.bz2 -C /tmp
mkdir /tmp/x264_build && cd /tmp/x264_build
../x264-master/configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" \
      --cross-prefix=${CROSS_PREFIX} --enable-static --disable-cli
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx264"

# Build x265
ENV X265_VERSION=3.5
RUN git clone https://bitbucket.org/multicoreware/x265_git -b ${X265_VERSION} --depth 1 /tmp/x265
RUN <<EOT
mkdir /tmp/x265_build && cd /tmp/x265_build
\
cp ../toolchains.cmake ./
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
      cat << EOS >> ./toolchains.cmake
SET(CMAKE_ASM_YASM_COMPILER yasm)
SET(CMAKE_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
EOS
fi
\
mkdir -p 8bit 10bit 12bit
\
cd 12bit
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 \
      -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 -DMAIN12=1 ../../x265/source
make -j $(nproc)
cp libx265.a ../8bit/libx265_main12.a
\
cd ../10bit
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 \
      -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 ../../x265/source
make -j $(nproc)
cp libx265.a ../8bit/libx265_main10.a
\
cd ../8bit
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. \
      -DLINKED_10BIT=1 -DLINKED_12BIT=1 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 \
      -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../../x265/source
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
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx265" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lpthread -lstdc++"

# Build libaom
RUN git clone https://aomedia.googlesource.com/aom -b master --depth 1 /tmp/aom
RUN <<EOT
mkdir /tmp/aom_build && cd /tmp/aom_build
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
      cmake -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 \
            -DCMAKE_TOOLCHAIN_FILE=../aom/build/cmake/toolchains/x86_64-mingw-gcc.cmake -DAOM_TARGET_CPU=x86_64 \
            -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../aom
else
      cmake -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 ../aom
fi
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
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
      cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 \
            -DOPUS_STACK_PROTECTOR=0 -DOPUS_FORTIFY_SOURCE=0 -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../opus-master
else
      cmake -DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 ../opus-master
fi
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopus"

# Build libogg, for vorbis
ADD https://github.com/xiph/ogg/archive/master.tar.gz /tmp/ogg-master.tar.gz
RUN <<EOT
tar xf /tmp/ogg-master.tar.gz -C /tmp
mkdir /tmp/ogg_build && cd /tmp/ogg_build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 \
      -DINSTALL_DOCS=0 -DBUILD_TESTING=0 -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../ogg-master
make -j $(nproc)
make install
EOT

# Build vorbis
ADD https://github.com/xiph/vorbis/archive/master.tar.gz /tmp/vorbis-master.tar.gz
RUN <<EOT
tar xf /tmp/vorbis-master.tar.gz -C /tmp
mkdir /tmp/vorbis_build && cd /tmp/vorbis_build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 \
      -DBUILD_TESTING=0 -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../vorbis-master
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvorbis"

# Build opencore-amr
ENV OPENCORE_AMI_VERSION=0.1.5
RUN curl -sL -o /tmp/opencore-amr-${OPENCORE_AMI_VERSION}.tar.gz https://download.sourceforge.net/opencore-amr/opencore-amr-${OPENCORE_AMI_VERSION}.tar.gz
RUN <<EOT
tar xf /tmp/opencore-amr-${OPENCORE_AMI_VERSION}.tar.gz -C /tmp
cd /tmp/opencore-amr-${OPENCORE_AMI_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopencore-amrnb --enable-libopencore-amrwb"

# Build vo-amrwbenc
ENV VO_AMRWBENC_VERSION=0.1.3
RUN curl -sL -o /tmp/vo-amrwbenc-${VO_AMRWBENC_VERSION}.tar.gz https://download.sourceforge.net/opencore-amr/vo-amrwbenc-${VO_AMRWBENC_VERSION}.tar.gz
RUN <<EOT
tar xf /tmp/vo-amrwbenc-${VO_AMRWBENC_VERSION}.tar.gz -C /tmp
cd /tmp/vo-amrwbenc-${VO_AMRWBENC_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvo-amrwbenc"

# Build mp3lame
RUN svn checkout https://svn.code.sf.net/p/lame/svn/trunk/lame /tmp/lame --non-interactive --trust-server-cert
RUN <<EOT
cd /tmp/lame
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared --enable-nasm --disable-decoder
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libmp3lame"


#
# Caption
#

# Build freetype
ENV FREETYPE_VERSION=2.11.1
RUN curl -sL -o /tmp/freetype-${FREETYPE_VERSION}.tar.xz https://download.sourceforge.net/freetype/freetype-${FREETYPE_VERSION}.tar.xz
RUN <<EOT
tar xf /tmp/freetype-${FREETYPE_VERSION}.tar.xz -C /tmp
cd /tmp/freetype-${FREETYPE_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared \
      --with-zlib=yes --with-png=yes --with-bzip2=yes
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfreetype"

# Build fribidi; Newer than 1.0.9 will cause a link error
ENV FRIBIDI_VERSION=1.0.9
ADD https://github.com/fribidi/fribidi/releases/download/v${FRIBIDI_VERSION}/fribidi-${FRIBIDI_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/fribidi-${FRIBIDI_VERSION}.tar.xz -C /tmp
cd /tmp/fribidi-${FRIBIDI_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --disable-shared --enable-static --disable-debug
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfribidi"

# Build libxml2
ENV LIBXML2_VERSION=2.9.12
ADD https://gitlab.gnome.org/GNOME/libxml2/-/archive/v${LIBXML2_VERSION}/libxml2-v${LIBXML2_VERSION}.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/libxml2-v${LIBXML2_VERSION}.tar.bz2 -C /tmp
mkdir /tmp/libxml2_build && cd /tmp/libxml2_build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchains.cmake -DBUILD_SHARED_LIBS=0 -DLIBXML2_WITH_FTP=0 \
      -DLIBXML2_WITH_HTTP=0 -DLIBXML2_WITH_PYTHON=0 -DLIBXML2_WITH_TESTS=0 \
      -DCMAKE_INSTALL_PREFIX=${LIBRARY_PREFIX} ../libxml2-v${LIBXML2_VERSION}
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libxml2"

# Build fontconfig
ENV FONTCONFIG_VERSION=2.13.94
ADD https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/fontconfig-${FONTCONFIG_VERSION}.tar.xz -C /tmp
cd /tmp/fontconfig-${FONTCONFIG_VERSION}
LIBS="-lm -lz -lbz2 -llzma" ./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared \
      --enable-iconv --enable-libxml2 --disable-docs --with-libiconv
make -j $(nproc)
make install
sed -i.bak -e "s%Libs.private: \(.*\)%Libs.private: \1 -lm -lz -lbz2 -llzma%g" ${PKG_CONFIG_PATH}/fontconfig.pc
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfontconfig"

# Build libharfbuzz
ENV HARFBUZZ_VERSION=3.2.0
ADD https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/harfbuzz-${HARFBUZZ_VERSION}.tar.xz -C /tmp
cd /tmp/harfbuzz-${HARFBUZZ_VERSION}
LIBS="-lbz2" ./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared \
      --with-freetype=yes --with-fontconfig=yes
make -j $(nproc)
make install
EOT

# Build libass
ENV LIBASS_VERSION=0.15.2
ADD https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/libass-${LIBASS_VERSION}.tar.xz -C /tmp
cd /tmp/libass-${LIBASS_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
if [ "${HOST_TARGET}" = "x86_64-w64-mingw32" ]; then
      sed -i.bak -e "s%Libs.private: \(.*\)%Libs.private: \1 -lgdi32 -ldwrite%g" ${PKG_CONFIG_PATH}/libass.pc
fi
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libass"

# Build libaribb24
ADD https://salsa.debian.org/multimedia-team/aribb24/-/archive/master/aribb24-master.tar.bz2 /tmp/
RUN <<EOT
tar xf /tmp/aribb24-master.tar.bz2 -C /tmp
cd /tmp/aribb24-master
./bootstrap
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaribb24"


#
# Graphic
#

# Build SDL

ENV SDL_VERSION=2.0.20
ADD https://www.libsdl.org/release/SDL2-${SDL_VERSION}.tar.gz /tmp/
RUN <<EOT
tar xf /tmp/SDL2-${SDL_VERSION}.tar.gz -C /tmp
cd /tmp/SDL2-${SDL_VERSION}
./configure --prefix=${LIBRARY_PREFIX} --host="${HOST_TARGET}" --enable-static --disable-shared
make -j $(nproc)
make install
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-sdl2"


#
# HWAccel
#

# Build NVcodec
ADD https://github.com/FFmpeg/nv-codec-headers/archive/master.tar.gz /tmp/nv-codec-headers-master.tar.gz
RUN <<EOT
tar xf /tmp/nv-codec-headers-master.tar.gz -C /tmp
cd /tmp/nv-codec-headers-master
make install "PREFIX=${LIBRARY_PREFIX}"
EOT
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-cuda-llvm --enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc"


#
# Copy artifacts
#
RUN <<EOT
mkdir /build
rm -r ${LIBRARY_PREFIX}/lib/python3.8
echo $FFMPEG_EXTRA_LIBS > ${LIBRARY_PREFIX}/ffmpeg_extra_libs
echo $FFMPEG_CONFIGURE_OPTIONS >${LIBRARY_PREFIX}/ffmpeg_configure_options
cp --archive --parents --no-dereference ${LIBRARY_PREFIX}/lib /build
cp --archive --parents --no-dereference ${LIBRARY_PREFIX}/include /build
cp --archive --parents --no-dereference ${LIBRARY_PREFIX}/ffmpeg_extra_libs /build
cp --archive --parents --no-dereference ${LIBRARY_PREFIX}/ffmpeg_configure_options /build
EOT


# final image
FROM scratch

COPY --from=ffmpeg-library-build /build /