#!/bin/bash

source ./base.sh

#
# Build Tools
#

# Download Cmake
CMAKE_VERSION=3.23.1
download_and_unpack_file "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-${HOST_OS}-${HOST_ARCH}.tar.gz"
case "$(uname)" in
Darwin)
  rm -f ./CMake.app/Contents/bin/cmake-gui
  cp -r ./CMake.app/Contents/bin/. ${PREFIX}/bin/
  cp -r ./CMake.app/Contents/share/. ${PREFIX}/share/
  ;;
Linux)
  cp -r ./bin/. ${PREFIX}/bin/
  cp -r ./share/. ${PREFIX}/share/
  ;;
esac

# Cmake build toolchain
cat << EOS > ${WORKDIR}/toolchains.cmake
SET(CMAKE_SYSTEM_NAME ${TARGET_OS})
SET(CMAKE_PREFIX_PATH ${PREFIX})
SET(CMAKE_INSTALL_PREFIX ${PREFIX})
SET(CMAKE_C_COMPILER ${CROSS_PREFIX}gcc)
SET(CMAKE_CXX_COMPILER ${CROSS_PREFIX}g++)
EOS

if [ "${TARGET_OS}" = "Windows" ]; then
  cat << EOS >> ${WORKDIR}/toolchains.cmake
SET(CMAKE_RC_COMPILER ${CROSS_PREFIX}windres)
SET(CMAKE_ASM_YASM_COMPILER yasm)
SET(CMAKE_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
EOS
fi


#
# Common Tools
#

# Build zlib
ZLIB_VERSION=1.2.11
download_and_unpack_file "https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz"
CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib ./configure --prefix=${PREFIX} --static
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-zlib")

# Build libpng
LIBPNG_VERSION=1.6.37
download_and_unpack_file "https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz"
mkcd ${WORKDIR}/libpng_build
do_cmake "-DPNG_SHARED=0 -DPNG_STATIC=1 -DPNG_TESTS=0" ../libpng-${LIBPNG_VERSION}
do_make_and_make_install

# Build libjpg
LIBJPG_VERSION=9e
download_and_unpack_file "http://www.ijg.org/files/jpegsrc.v${LIBJPG_VERSION}.tar.gz"
do_configure
do_make_and_make_install

# Build openjpeg
download_and_unpack_file "https://github.com/uclouvain/openjpeg/archive/master.tar.gz" openjpeg-master.tar.gz
mkcd ${WORKDIR}/openjpeg_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 -DBUILD_CODEC=0" ../openjpeg-master
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopenjpeg")

# Build webp
git_clone "https://chromium.googlesource.com/webm/libwebp.git"
export LIBPNG_CONFIG="${PREFIX}/bin/libpng-config --static"
do_configure "--disable-wic"
do_make_and_make_install
unset LIBPNG_CONFIG
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libwebp")

# Build bzip2
BZIP2_VERSION=1.0.8
download_and_unpack_file "https://www.sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz"
make CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib libbz2.a
install -m 644 bzlib.h ${PREFIX}/include
install -m 644 libbz2.a ${PREFIX}/lib
cat <<EOS > ${PKG_CONFIG_PATH}/bz2.pc
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
sharedlibdir=\${libdir}
includedir=\${prefix}/include

Name: bzip2
Description: bzip2 compression library
Version: ${BZIP2_VERSION}

Requires:
Libs: -L\${libdir} -L\${sharedlibdir}
Cflags: -I\${includedir}
EOS

# Build lzma
LZMA_VERSION=5.2.5
download_and_unpack_file "https://sourceforge.net/projects/lzmautils/files/xz-${LZMA_VERSION}.tar.xz"
do_configure "--disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-lzma")

# Build Nettle
NETTLE_VERSION=3.7.3
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/nettle/nettle-${NETTLE_VERSION}.tar.gz"
do_configure "--libdir=${PREFIX}/lib --enable-mini-gmp --disable-openssl --disable-documentation"
do_make_and_make_install

# Build GMP
GMP_VERSION=6.2.1
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/gmp/gmp-${GMP_VERSION}.tar.lz"
do_configure
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gmp")

# Build Libtasn1
LIBTASN1_VERSION=4.18.0
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz"
do_configure
do_make_and_make_install

# Build libunistring
LIBUNISTRING_VERSION=1.0
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libunistring/libunistring-${LIBUNISTRING_VERSION}.tar.xz"
do_configure
do_make_and_make_install

# Build iconv
ICONV_VERSION=1.16
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libiconv/libiconv-${ICONV_VERSION}.tar.gz"
do_configure
make install-lib
FFMPEG_CONFIGURE_OPTIONS+=("--enable-iconv")

# Build GnuTLS
GNUTLS_VERSION=3.7.4
download_and_unpack_file "https://mirrors.dotsrc.org/gcrypt/gnutls/v3.7/gnutls-${GNUTLS_VERSION}.tar.xz"
do_configure "--disable-tests --disable-doc --disable-tools --without-p11-kit"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gnutls")

# Build SRT
download_and_unpack_file "https://github.com/Haivision/srt/archive/master.tar.gz" srt-master.tar.gz
mkcd ${WORKDIR}/srt_build
do_cmake "-DENABLE_SHARED=0 -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin
          -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_APPS=0 -DUSE_STATIC_LIBSTDCXX=1
          -DUSE_ENCLIB=gnutls" ../srt-master
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libsrt")


#
# Video
#

# Build libvpx
download_and_unpack_file "https://github.com/webmproject/libvpx/archive/master.tar.gz" libvpx-master.tar.gz
if [ "${TARGET_OS}" = "Windows" ]; then
  CROSS=${CROSS_PREFIX} ./configure --prefix="${PREFIX}" --target=x86_64-win64-gcc --disable-examples --disable-docs --disable-unit-tests --as=yasm
else
  ./configure --prefix="${PREFIX}" --disable-examples --disable-docs --disable-unit-tests --as=yasm
fi
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvpx")

# Build x264
download_and_unpack_file "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2"
do_configure "--cross-prefix=${CROSS_PREFIX} --disable-cli"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx264")

# Build x265
X265_VERSION=3.5
git_clone "https://bitbucket.org/multicoreware/x265_git" "${X265_VERSION}"
mkcd ${WORKDIR}/x265_build
mkdir -p 8bit 10bit 12bit

cd 12bit
do_cmake "-DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 -DMAIN12=1" ../../x265_git/source
make -j ${CPU_NUM}
cp libx265.a ../8bit/libx265_main12.a

cd ../10bit
do_cmake "-DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0" ../../x265_git/source
make -j ${CPU_NUM}
cp libx265.a ../8bit/libx265_main10.a

cd ../8bit
do_cmake '-DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=1 -DLINKED_12BIT=1
          -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0' ../../x265_git/source
make -j ${CPU_NUM}

mv libx265.a libx265_main.a

ar -M <<EOS
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOS

make install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx265")
FFMPEG_EXTRA_LIBS+=("-lpthread" "-lstdc++")

# Build libaom
git_clone https://aomedia.googlesource.com/aom
mkcd ${WORKDIR}/aom_build
if [ "${TARGET_OS}" = "Windows" ]; then
  cmake -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 \
        -DCMAKE_TOOLCHAIN_FILE=../aom/build/cmake/toolchains/x86_64-mingw-gcc.cmake -DAOM_TARGET_CPU=x86_64 \
        -DCMAKE_INSTALL_PREFIX=${PREFIX} ../aom
else
  do_cmake "-DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0" ../aom
fi
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libaom")


#
# Audio
#

# Build opus
download_and_unpack_file "https://github.com/xiph/opus/archive/master.tar.gz" opus-master.tar.gz
mkcd ${WORKDIR}/opus_build
if [ "${TARGET_OS}" = "Windows" ]; then
  do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 -DOPUS_STACK_PROTECTOR=0 -DOPUS_FORTIFY_SOURCE=0" ../opus-master
else
  do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0" ../opus-master
fi
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopus")

# Build libogg, for vorbis
download_and_unpack_file "https://github.com/xiph/ogg/archive/master.tar.gz" ogg-master.tar.gz
mkcd ${WORKDIR}/ogg_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DINSTALL_DOCS=0 -DBUILD_TESTING=0" ../ogg-master
do_make_and_make_install

# Build vorbis
download_and_unpack_file "https://github.com/xiph/vorbis/archive/master.tar.gz" vorbis-master.tar.gz
mkcd ${WORKDIR}/vorbis_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DBUILD_TESTING=0" ../vorbis-master
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvorbis")

# Build opencore-amr
OPENCORE_AMI_VERSION=0.1.5
download_and_unpack_file "https://download.sourceforge.net/opencore-amr/opencore-amr-${OPENCORE_AMI_VERSION}.tar.gz"
do_configure
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopencore-amrnb" "--enable-libopencore-amrwb")

# Build vo-amrwbenc
VO_AMRWBENC_VERSION=0.1.3
download_and_unpack_file "https://download.sourceforge.net/opencore-amr/vo-amrwbenc-${VO_AMRWBENC_VERSION}.tar.gz"
do_configure
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvo-amrwbenc")

# Build mp3lame
svn_checkout "https://svn.code.sf.net/p/lame/svn/trunk/lame"
do_configure "--enable-nasm --disable-decoder"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libmp3lame")


#
# Caption
#

# Build freetype
FREETYPE_VERSION=2.12.0
download_and_unpack_file "https://download.sourceforge.net/freetype/freetype-${FREETYPE_VERSION}.tar.xz"
do_configure "--with-zlib=yes --with-png=yes --with-bzip2=yes"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libfreetype")

# Build fribidi
FRIBIDI_VERSION=1.0.12
download_and_unpack_file "https://github.com/fribidi/fribidi/releases/download/v${FRIBIDI_VERSION}/fribidi-${FRIBIDI_VERSION}.tar.xz"
do_configure "--disable-debug"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libfribidi")

# Build libxml2
LIBXML2_VERSION=2.9.13
download_and_unpack_file "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v${LIBXML2_VERSION}/libxml2-v${LIBXML2_VERSION}.tar.bz2"
mkcd ${WORKDIR}/libxml2_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DLIBXML2_WITH_FTP=0 -DLIBXML2_WITH_HTTP=0 -DLIBXML2_WITH_PYTHON=0 -DLIBXML2_WITH_TESTS=0" ../libxml2-v${LIBXML2_VERSION}
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libxml2")

# Build fontconfig
FONTCONFIG_VERSION=2.14.0
download_and_unpack_file "https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.xz"
export LIBS="-lm -lz -lbz2 -llzma"
do_configure "--enable-iconv --enable-libxml2 --disable-docs --with-libiconv"
do_make_and_make_install
sed -i -e "s%Libs.private: \(.*\)%Libs.private: \1 -lm -lz -lbz2 -llzma%g" ${PKG_CONFIG_PATH}/fontconfig.pc
unset LIBS
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libfontconfig")

# Build libharfbuzz
HARFBUZZ_VERSION=4.2.0
download_and_unpack_file "https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
export LIBS="-lbz2"
do_configure "--with-freetype=yes --with-icu=no"
do_make_and_make_install
unset LIBS

# Build libass
LIBASS_VERSION=0.15.2
download_and_unpack_file "https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz"
do_configure
do_make_and_make_install
if [ "${TARGET_OS}" = "Windows" ]; then
  sed -i -e "s%Libs.private: \(.*\)%Libs.private: \1 -lgdi32 -ldwrite%g" ${PKG_CONFIG_PATH}/libass.pc
fi
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libass")

# Build libaribb24
download_and_unpack_file "https://salsa.debian.org/multimedia-team/aribb24/-/archive/master/aribb24-master.tar.bz2"
do_configure
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libaribb24")


#
# Graphic
#

# Build SDL
SDL_VERSION=2.0.20
download_and_unpack_file "https://www.libsdl.org/release/SDL2-${SDL_VERSION}.tar.gz"
do_configure
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-sdl2")


#
# HWAccel
#

# Build NVcodec
download_and_unpack_file "https://github.com/FFmpeg/nv-codec-headers/archive/master.tar.gz" nv-codec-headers-master.tar.gz
make install "PREFIX=${PREFIX}"
FFMPEG_CONFIGURE_OPTIONS+=("--enable-cuda-llvm" "--enable-ffnvcodec" "--enable-cuvid" "--enable-nvdec" "--enable-nvenc")


#
# Save options
#

echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options