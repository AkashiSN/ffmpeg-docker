#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${SCRIPT_DIR}/base.sh

rm -rf ${ARTIFACT_DIR}
mkdir -p ${RUNTIME_LIB_DIR}
mkdir -p ${ARTIFACT_DIR}


#==============================================================================
# Build Libraries
#==============================================================================

#
# Common library
#

# Build xorg-macros
XORG_MACROS_REPO="https://gitlab.freedesktop.org/xorg/util/macros.git"
XORG_MACROS_TAG_PREFIX="util-macros-"
XORG_MACROS_VERSION="1.20.1" # get_latest_tag ${XORG_MACROS_REPO} ${XORG_MACROS_TAG_PREFIX}
git_clone ${XORG_MACROS_REPO} ${XORG_MACROS_TAG_PREFIX}${XORG_MACROS_VERSION} ${XORG_MACROS_VERSION}
do_configure
do_make_and_make_install

# Build zlib
ZLIB_REPO="https://github.com/madler/zlib.git"
ZLIB_TAG_PREFIX="v"
ZLIB_VERSION="1.3.1" # get_latest_tag ${ZLIB_REPO} ${ZLIB_TAG_PREFIX}
git_clone ${ZLIB_REPO} ${ZLIB_TAG_PREFIX}${ZLIB_VERSION}
CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib ./configure --prefix=${PREFIX} --static
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-zlib")

# Build bzip2
BZIP2_REPO="https://gitlab.com/bzip2/bzip2.git"
BZIP2_TAG_PREFIX="bzip2-"
BZIP2_VERSION="1.0.8" # get_latest_tag ${BZIP2_REPO} ${BZIP2_TAG_PREFIX}
git_clone ${BZIP2_REPO} ${BZIP2_TAG_PREFIX}${BZIP2_VERSION} ${BZIP2_VERSION}
make CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib libbz2.a
install -m 644 bzlib.h ${PREFIX}/include
install -m 644 libbz2.a ${PREFIX}/lib
cat <<EOS > ${PKG_CONFIG_PATH}/bz2.pc
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: bzip2
Description: A file compression library
Version: ${BZIP2_VERSION}

Libs: -L\${libdir} -lbz2
Cflags: -I\${includedir}
EOS
ln -s ${PKG_CONFIG_PATH}/bz2.pc ${PKG_CONFIG_PATH}/bzip2.pc

# Build lzma
LZMA_REPO="https://github.com/tukaani-project/xz.git"
LZMA_TAG_PREFIX="v"
LZMA_VERSION="5.6.2" # get_latest_tag ${LZMA_REPO} ${LZMA_TAG_PREFIX}
git_clone ${LZMA_REPO} ${LZMA_TAG_PREFIX}${LZMA_VERSION}
./autogen.sh --no-po4a --no-doxygen
do_configure "--enable-static --disable-shared --with-pic --disable-symbol-versions
              --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-lzma")

# Build Nettle (for gmp,gnutls)
NETTLE_URL="https://ftp.jaist.ac.jp/pub/GNU/nettle"
NETTLE_PREFIX="nettle-"
NETTLE_VERSION="3.10" # get_latest_version ${NETTLE_URL} ${NETTLE_PREFIX}
download_and_unpack_file ${NETTLE_URL}/${NETTLE_PREFIX}${NETTLE_VERSION}.tar.gz
do_configure "--enable-static --disable-shared --libdir=${PREFIX}/lib --enable-mini-gmp --disable-openssl --disable-documentation"
do_make_and_make_install

# Build GMP
GMP_URL="https://ftp.jaist.ac.jp/pub/GNU/gmp"
GMP_PREFIX="gmp-"
GMP_VERSION="6.3.0" # get_latest_version ${GMP_URL} ${GMP_PREFIX}
download_and_unpack_file ${GMP_URL}/${GMP_PREFIX}${GMP_VERSION}.tar.xz
do_configure "--enable-static --disable-shared --with-pic"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gmp")

# Build libtasn1 (for gnutls)
LIBTASN1_URL="https://ftp.jaist.ac.jp/pub/GNU/libtasn1"
LIBTASN1_PREFIX="libtasn1-"
LIBTASN1_VERSION="4.19.0" # get_latest_version ${LIBTASN1_URL} ${LIBTASN1_PREFIX}
download_and_unpack_file ${LIBTASN1_URL}/${LIBTASN1_PREFIX}${LIBTASN1_VERSION}.tar.gz
do_configure "--enable-static --disable-shared"
do_make_and_make_install

# Build libunistring (for gnutls)
LIBUNISTRING_URL="https://ftp.jaist.ac.jp/pub/GNU/libunistring"
LIBUNISTRING_PREFIX="libunistring-"
LIBUNISTRING_VERSION="1.2" # get_latest_version ${LIBUNISTRING_URL} ${LIBUNISTRING_PREFIX}
download_and_unpack_file ${LIBUNISTRING_URL}/${LIBUNISTRING_PREFIX}${LIBUNISTRING_VERSION}.tar.xz
do_configure "--enable-static --disable-shared"
do_make_and_make_install

# Build libiconv
ICONV_URL="https://ftp.jaist.ac.jp/pub/GNU/libiconv"
ICONV_PREFIX="libiconv-"
ICONV_VERSION="1.17" # get_latest_version ${ICONV_URL} ${ICONV_PREFIX}
download_and_unpack_file ${ICONV_URL}/${ICONV_PREFIX}${ICONV_VERSION}.tar.gz
do_configure "--enable-static --disable-shared --with-pic --enable-extra-encodings"
make install-lib
FFMPEG_CONFIGURE_OPTIONS+=("--enable-iconv")

# Build GnuTLS
GNUTLS_URL="https://www.gnupg.org/ftp/gcrypt/gnutls"
GNUTLS_PREFIX="gnutls-"
GNUTLS_MAJOR_VERSION="v3.8"
GNUTLS_VERSION="3.8.7.1" # get_latest_version ${GNUTLS_URL} ${GNUTLS_PREFIX} ${GNUTLS_MAJOR_VERSION}
download_and_unpack_file ${GNUTLS_URL}/${GNUTLS_MAJOR_VERSION}/${GNUTLS_PREFIX}${GNUTLS_VERSION}.tar.xz
do_configure "--enable-static --disable-shared --with-pic --disable-tests --disable-doc --disable-tools --without-p11-kit"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gnutls")

# Build SRT
SRT_REPO="https://github.com/Haivision/srt.git"
SRT_TAG_PREFIX="v"
SRT_VERSION="1.5.3" # get_latest_tag ${SRT_REPO} ${SRT_TAG_PREFIX}
git_clone ${SRT_REPO} ${SRT_TAG_PREFIX}${SRT_VERSION}
mkcd build
do_cmake "-DENABLE_SHARED=0 -DENABLE_APPS=0 -DENABLE_CXX_DEPS=1 -DUSE_STATIC_LIBSTDCXX=1
          -DENABLE_ENCRYPTION=1 -DUSE_ENCLIB=gnutls" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libsrt")

# Build libpciaccess (Linux only)
LIBPCIACCESS_REPO="https://gitlab.freedesktop.org/xorg/lib/libpciaccess.git"
LIBPCIACCESS_TAG_PREFIX="libpciaccess-"
LIBPCIACCESS_VERSION="0.18.1" # get_latest_tag ${LIBPCIACCESS_REPO} ${LIBPCIACCESS_TAG_PREFIX}
git_clone ${LIBPCIACCESS_REPO} ${LIBPCIACCESS_TAG_PREFIX}${LIBPCIACCESS_VERSION} ${LIBPCIACCESS_VERSION}
mkcd build
do_meson "-Dzlib=enabled" ../
do_ninja_and_ninja_install
gen_implib ${PREFIX}/lib/{libpciaccess.so.0,libpciaccess.a}
cp_archive ${PREFIX}/lib/libpciaccess.so* ${RUNTIME_LIB_DIR}
rm ${PREFIX}/lib/libpciaccess.so*


#
# Image
#

# Build libpng (for libwebp)
LIBPNG_REPO="https://github.com/glennrp/libpng.git"
LIBPNG_TAG_PREFIX="v"
LIBPNG_VERSION="1.6.44" # get_latest_tag ${LIBPNG_REPO} ${LIBPNG_TAG_PREFIX}
git_clone ${LIBPNG_REPO} ${LIBPNG_TAG_PREFIX}${LIBPNG_VERSION}
do_configure "--enable-static --disable-shared --with-pic"
do_make_and_make_install

# Build libjpeg (for libwebp)
LIBJPEG_VERSION="9f"
download_and_unpack_file "http://www.ijg.org/files/jpegsrc.v${LIBJPEG_VERSION}.tar.gz"
do_configure "--enable-static --disable-shared --with-pic"
do_make_and_make_install

# Build openjpeg
OPENJPEG_REPO="https://github.com/uclouvain/openjpeg.git"
OPENJPEG_TAG_PREFIX="v"
OPENJPEG_VERSION="2.5.2" # get_latest_tag ${OPENJPEG_REPO} ${OPENJPEG_TAG_PREFIX}
git_clone ${OPENJPEG_REPO} ${OPENJPEG_TAG_PREFIX}${OPENJPEG_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DDBUILD_PKGCONFIG_FILES=1 -DBUILD_CODEC=0 -DWITH_ASTYLE=0 -DBUILD_TESTING=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopenjpeg")

# Build libwebp
LIBWEBP_REPO="https://chromium.googlesource.com/webm/libwebp.git"
LIBWEBP_TAG_PREFIX="v"
LIBWEBP_VERSION="1.4.0" # get_latest_tag ${LIBWEBP_REPO} ${LIBWEBP_TAG_PREFIX}
git_clone ${LIBWEBP_REPO} ${LIBWEBP_TAG_PREFIX}${LIBWEBP_VERSION}
do_configure "--enable-static --disable-shared --with-pic --enable-libwebpmux --enable-png --enable-jpeg
              --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-tiff --disable-gif"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libwebp")


#
# Video
#

# Build libvpx
LIBVPX_REPO="https://chromium.googlesource.com/webm/libvpx.git"
LIBVPX_TAG_PREFIX="v"
LIBVPX_VERSION="1.14.1" # get_latest_tag ${LIBVPX_REPO} ${LIBVPX_TAG_PREFIX}
git_clone ${LIBVPX_REPO} ${LIBVPX_TAG_PREFIX}${LIBVPX_VERSION}
./configure --prefix="${PREFIX}" --disable-shared --enable-static --enable-pic --disable-examples \
  --disable-tools --disable-docs --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvpx")

# Build x264
download_and_unpack_file "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2"
do_configure "--cross-prefix=${CROSS_PREFIX} --disable-shared --enable-static --enable-pic --disable-cli --disable-lavf --disable-swscale"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx264")

# Build x265
X265_VERSION="3.5"
git_clone "https://bitbucket.org/multicoreware/x265_git" "${X265_VERSION}"
mkcd build
mkdir -p 8bit 10bit 12bit

cd 12bit
do_cmake "-DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 -DMAIN12=1" ../../source
make -j ${CPU_NUM}
cp libx265.a ../8bit/libx265_main12.a

cd ../10bit
do_cmake "-DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0" ../../source
make -j ${CPU_NUM}
cp libx265.a ../8bit/libx265_main10.a

cd ../8bit
do_cmake '-DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=1 -DLINKED_12BIT=1
          -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0' ../../source
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

# Build libaom
LIBAOM_REPO="https://aomedia.googlesource.com/aom.git"
LIBAOM_TAG_PREFIX="v"
LIBAOM_VERSION="3.10.0" # get_latest_tag ${LIBAOM_REPO} ${LIBAOM_TAG_PREFIX}
git_clone ${LIBAOM_REPO} ${LIBAOM_TAG_PREFIX}${LIBAOM_VERSION}
mkcd _build
do_cmake "-DAOM_TARGET_CPU=x86_64 -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libaom")

# Build vmaf
VMAF_REPO="https://github.com/Netflix/vmaf.git"
VMAF_TAG_PREFIX="v"
VMAF_VERSION="2.3.1" # get_latest_tag ${VMAF_REPO} ${VMAF_TAG_PREFIX}
git_clone ${VMAF_REPO} ${VMAF_TAG_PREFIX}${VMAF_VERSION}
mkcd build
do_meson "--default-library=static -Denable_tests=false -Denable_docs=false" ../libvmaf
do_ninja_and_ninja_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvmaf")


#
# Audio
#

# Build opus
OPUS_REPO="https://github.com/xiph/opus.git"
OPUS_TAG_PREFIX="v"
OPUS_VERSION="1.5.2" # get_latest_tag ${OPUS_REPO} ${OPUS_TAG_PREFIX}
git_clone ${OPUS_REPO} ${OPUS_TAG_PREFIX}${OPUS_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopus")

# Build libogg, for vorbis
OGG_REPO="https://github.com/xiph/ogg.git"
OGG_TAG_PREFIX="v"
OGG_VERSION="1.3.5" # get_latest_tag ${OGG_REPO} ${OGG_TAG_PREFIX}
git_clone ${OGG_REPO} ${OGG_TAG_PREFIX}${OGG_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DINSTALL_DOCS=0 -DBUILD_TESTING=0" ..
do_make_and_make_install

# Build vorbis
VORBIS_REPO="https://github.com/xiph/vorbis.git"
VORBIS_TAG_PREFIX="v"
VORBIS_VERSION="1.3.7" # get_latest_tag ${VORBIS_REPO} ${VORBIS_TAG_PREFIX}
git_clone ${VORBIS_REPO} ${VORBIS_TAG_PREFIX}${VORBIS_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvorbis")

# Build opencore-amr
OPENCORE_AMI_VERSION="0.1.6"
download_and_unpack_file "https://download.sourceforge.net/opencore-amr/opencore-amr-${OPENCORE_AMI_VERSION}.tar.gz"
do_configure "--disable-shared --enable-static"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopencore-amrnb" "--enable-libopencore-amrwb")

# Build vo-amrwbenc
VO_AMRWBENC_VERSION="0.1.3"
download_and_unpack_file "https://download.sourceforge.net/opencore-amr/vo-amrwbenc-${VO_AMRWBENC_VERSION}.tar.gz"
do_configure "--disable-shared --enable-static"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvo-amrwbenc")

# Build mp3lame
svn_checkout "https://svn.code.sf.net/p/lame/svn/trunk/lame"
do_configure "--disable-shared --enable-static --enable-nasm --disable-decoder --disable-gtktest --disable-cpml --disable-frontend"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libmp3lame")


#
# Caption
#

# Build freetype
FREETYPE_VERSION="VER-2-13-2"
git_clone "https://gitlab.freedesktop.org/freetype/freetype.git" ${FREETYPE_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DFT_REQUIRE_ZLIB=1 -DFT_REQUIRE_BZIP2=1 -DFT_REQUIRE_PNG=1 -DFT_DISABLE_HARFBUZZ=1" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libfreetype")

# Build fribidi
FRIBIDI_VERSION="1.0.13"
git_clone "https://github.com/fribidi/fribidi.git" v${FRIBIDI_VERSION}
do_configure "--disable-shared --enable-static --disable-debug"
do_make_and_make_install 1
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libfribidi")

# Build libxml2
LIBXML2_VERSION="2.11.5"
git_clone "https://gitlab.gnome.org/GNOME/libxml2.git" v${LIBXML2_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DLIBXML2_WITH_FTP=0 -DLIBXML2_WITH_HTTP=0 -DLIBXML2_WITH_PYTHON=0
          -DLIBXML2_WITH_SAX1=1 -DLIBXML2_WITH_TESTS=0" ..
do_make_and_make_install
sed -i -e "s%Libs: \(.*\)%Libs: \1 -lz -llzma%g" ${PKG_CONFIG_PATH}/libxml-2.0.pc
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libxml2")

# Build fontconfig
FONTCONFIG_VERSION="2.14.2"
git_clone "https://gitlab.freedesktop.org/fontconfig/fontconfig.git" ${FONTCONFIG_VERSION}
do_configure "--disable-shared --enable-static --enable-iconv --enable-libxml2 --disable-docs --with-libiconv"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libfontconfig")

# Build libharfbuzz
HARFBUZZ_VERSION="8.1.1"
git_clone "https://github.com/harfbuzz/harfbuzz.git" ${HARFBUZZ_VERSION}
mkcd build
do_meson "--default-library=static -Dfreetype=enabled -Dicu=disabled -Dtests=disabled" ..
do_ninja_and_ninja_install

# Build libass
LIBASS_VERSION="0.17.1"
git_clone "https://github.com/libass/libass.git" ${LIBASS_VERSION}
do_configure "--disable-shared --enable-static"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libass")

# Build libaribb24
download_and_unpack_file "https://salsa.debian.org/multimedia-team/aribb24/-/archive/master/aribb24-master.tar.bz2"
do_configure "--disable-shared --enable-static"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libaribb24")


#
# Graphic
#

# Build SDL
SDL_URL="https://www.libsdl.org/release"
SDL_PREFIX="SDL2-"
SDL_VERSION="2.28.3" # get_latest_version ${SDL_URL} ${SDL_PREFIX}
download_and_unpack_file ${SDL_URL}/${SDL_PREFIX}${SDL_VERSION}.tar.gz
do_configure "--disable-shared --enable-static"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-sdl2")


#
# HWAccel
#

# Build NVcodec
NVCODEC_REPO="https://github.com/FFmpeg/nv-codec-headers.git"
NVCODEC_TAG_PREFIX="n11."
# https://github.com/m-ab-s/media-autobuild_suite/issues/2522#issuecomment-1891625706
NVCODEC_VERSION="1.5.3" # get_latest_tag ${NVCODEC_REPO} ${NVCODEC_TAG_PREFIX}
git_clone ${NVCODEC_REPO} ${NVCODEC_TAG_PREFIX}${NVCODEC_VERSION}
make install "PREFIX=${PREFIX}"
FFMPEG_CONFIGURE_OPTIONS+=("--enable-cuda-llvm" "--enable-ffnvcodec" "--enable-cuvid" "--enable-nvdec" "--enable-nvenc")

# Build libdrm (Linux only)
LIBDRM_REPO="https://gitlab.freedesktop.org/mesa/drm.git"
LIBDRM_TAG_PREFIX="libdrm-"
LIBDRM_VERSION="2.4.123" # get_latest_tag ${LIBDRM_REPO} ${LIBDRM_TAG_PREFIX}
git_clone ${LIBDRM_REPO} ${LIBDRM_TAG_PREFIX}${LIBDRM_VERSION} ${LIBDRM_VERSION}
mkcd build
do_meson "-Ddefault_library=shared -Dudev=false -Dcairo-tests=disabled -Dvalgrind=disabled -Dexynos=disabled
          -Dfreedreno=disabled -Domap=disabled -Detnaviv=disabled -Dintel=enabled -Dnouveau=enabled
          -Dradeon=enabled -Damdgpu=enabled" ..
do_ninja_and_ninja_install
for pc in ${PKG_CONFIG_PATH}/libdrm*.pc; do
  sed -i -e "s%Libs: \(.*\)%Libs: \1 -ldl%g" ${pc}
done
gen_implib ${PREFIX}/lib/{libdrm.so.2,libdrm.a}
gen_implib ${PREFIX}/lib/{libdrm_intel.so.1,libdrm_intel.a}
gen_implib ${PREFIX}/lib/{libdrm_amdgpu.so.1,libdrm_amdgpu.a}
gen_implib ${PREFIX}/lib/{libdrm_nouveau.so.2,libdrm_nouveau.a}
gen_implib ${PREFIX}/lib/{libdrm_radeon.so.1,libdrm_radeon.a}
cp_archive ${PREFIX}/lib/libdrm*.so* ${RUNTIME_LIB_DIR}
rm ${PREFIX}/lib/libdrm*.so*
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libdrm")

# Build libva (Linux only)
LIBVA_REPO="https://github.com/intel/libva.git"
LIBVA_VERSION="2.22.0" # get_latest_tag ${LIBVA_REPO}
git_clone ${LIBVA_REPO} ${LIBVA_VERSION}
do_configure "--enable-shared --disable-static --with-pic --disable-docs --enable-drm
              --disable-x11 --disable-glx --disable-wayland --sysconfdir=/etc"
do_make_and_make_install
gen_implib ${PREFIX}/lib/{libva.so.2,libva.a}
gen_implib ${PREFIX}/lib/{libva-drm.so.2,libva-drm.a}
cp_archive ${PREFIX}/lib/libva{,-drm}.so* ${RUNTIME_LIB_DIR}
rm ${PREFIX}/lib/libva{,-drm}{.so*,.la}
FFMPEG_CONFIGURE_OPTIONS+=("--enable-vaapi")

# Build libva-utils (Linux only)
LIBVA_UTILS_REPO="https://github.com/intel/libva-utils.git"
LIBVA_UTILS_VERSION="2.22.0" # get_latest_tag ${LIBVA_UTILS_REPO}
git_clone ${LIBVA_UTILS_REPO} ${LIBVA_UTILS_VERSION}
do_configure "--with-pic --enable-drm --disable-x11"
do_make_and_make_install
cp_archive ${PREFIX}/bin/vainfo ${ARTIFACT_DIR}

# Build gmmlib (Linux only)
GMMLIB_REPO="https://github.com/intel/gmmlib.git"
GMMLIB_TAG_PREFIX="intel-gmmlib-"
GMMLIB_VERSION="22.5.2" # get_latest_tag ${GMMLIB_REPO} ${GMMLIB_TAG_PREFIX}
git_clone ${GMMLIB_REPO} ${GMMLIB_TAG_PREFIX}${GMMLIB_VERSION} ${GMMLIB_VERSION}
mkcd build
do_cmake ..
do_make_and_make_install
cp_archive ${PREFIX}/lib/libigdgmm.so* ${RUNTIME_LIB_DIR}

# Build media-driver (Linux only)
MEDIA_DRIVER_REPO="https://github.com/intel/media-driver.git"
MEDIA_DRIVER_TAG_PREFIX="intel-media-"
MEDIA_DRIVER_VERSION="24.3.3" # get_latest_tag ${MEDIA_DRIVER_REPO} ${MEDIA_DRIVER_TAG_PREFIX}2
git_clone ${MEDIA_DRIVER_REPO} ${MEDIA_DRIVER_TAG_PREFIX}${MEDIA_DRIVER_VERSION} ${MEDIA_DRIVER_VERSION}
mkcd build
do_cmake "-DENABLE_KERNELS=1 -DENABLE_NONFREE_KERNELS=1 -DENABLE_PRODUCTION_KMD=1" ..
do_make_and_make_install
cp_archive ${PREFIX}/lib/dri ${RUNTIME_LIB_DIR}
cp_archive ${PREFIX}/lib/libigfxcmrt.so* ${RUNTIME_LIB_DIR}

# Build intel-vaapi-driver (Linux only)
INTEL_VAAPI_DRIVER_REPO="https://github.com/intel/intel-vaapi-driver.git"
INTEL_VAAPI_DRIVER_VERSION="2.4.1" # get_latest_tag ${INTEL_VAAPI_DRIVER_REPO}
git_clone ${INTEL_VAAPI_DRIVER_REPO} ${INTEL_VAAPI_DRIVER_VERSION}
mkcd build
do_meson "-Ddriverdir=${PREFIX}/lib/dri" ..
do_ninja_and_ninja_install
do_strip ${PREFIX}/lib/dri "*.so"
cp_archive ${PREFIX}/lib/dri ${RUNTIME_LIB_DIR}

# Build oneVPL gpu runtime (Linux only)
ONEVPL_INTEL_GPU_REPO="https://github.com/oneapi-src/oneVPL-intel-gpu.git"
ONEVPL_INTEL_GPU_TAG_PREFIX="intel-onevpl-"
ONEVPL_INTEL_GPU_VERSION="24.3.3" # get_latest_tag ${ONEVPL_INTEL_GPU_REPO} ${ONEVPL_INTEL_GPU_TAG_PREFIX}
git_clone ${ONEVPL_INTEL_GPU_REPO} ${ONEVPL_INTEL_GPU_TAG_PREFIX}${ONEVPL_INTEL_GPU_VERSION} ${ONEVPL_INTEL_GPU_VERSION}
mkcd build
do_cmake "-DBUILD_RUNTIME=1 -DBUILD_TESTS=0" ..
do_make_and_make_install
cp_archive ${PREFIX}/lib/libmfx-gen ${RUNTIME_LIB_DIR}
cp_archive ${PREFIX}/lib/libmfx-gen.so* ${RUNTIME_LIB_DIR}

# Build MediaSDK (Linux only)
MEDIASDK_VERSION="23.2.2"
MEDIASDK_TAG="intel-mediasdk-${MEDIASDK_VERSION}"
git_clone "https://github.com/Intel-Media-SDK/MediaSDK.git" ${MEDIASDK_TAG} ${MEDIASDK_VERSION}
mkcd build
do_cmake ..
do_make_and_make_install
gen_implib ${PREFIX}/lib/{libmfx.so.1,libmfx.a}
cp_archive ${PREFIX}/lib/mfx ${RUNTIME_LIB_DIR}
cp_archive ${PREFIX}/lib/libmfx.so* ${RUNTIME_LIB_DIR}
cp_archive ${PREFIX}/lib/libmfxhw64.so* ${RUNTIME_LIB_DIR}
rm ${PREFIX}/lib/libmfx.so*

# Build libvpl (Common)
VPL_REPO="https://github.com/intel/libvpl.git"
VPL_TAG_PREFIX="v"
VPL_VERSION="2023.4.0" # get_latest_tag ${VPL_REPO} ${VPL_TAG_PREFIX}
git_clone ${VPL_REPO} ${VPL_TAG_PREFIX}${VPL_VERSION}
mkcd build
do_cmake "-DBUILD_DISPATCHER=1 -DBUILD_DEV=1 -DBUILD_PREVIEW=0 -DBUILD_TOOLS=0
          -DBUILD_TOOLS_ONEVPL_EXPERIMENTAL=0 -DINSTALL_EXAMPLE_CODE=0 -DBUILD_SHARED_LIBS=0 -DBUILD_TESTS=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvpl")


#------------------------------------------------------------------------------
# Prepare FFmpeg Build Options
#------------------------------------------------------------------------------

# Write library options to files for FFmpeg configure
echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options


#==============================================================================
# Build FFmpeg
#==============================================================================

# Build ffmpeg
FFMPEG_VERSION="${FFMPEG_VERSION:-"8.0"}"
git_clone "https://github.com/FFmpeg/FFmpeg.git" n${FFMPEG_VERSION}

FFMPEG_LIBVPL_SUPPORT_VERSION="6.0"
# Check if the current FFMPEG_VERSION is greater than to the version that supports libvpl.
if [ "${FFMPEG_VERSION}" != "${FFMPEG_LIBVPL_SUPPORT_VERSION}" ]; then
  if [ "$(echo -e "${FFMPEG_VERSION}\n${FFMPEG_LIBVPL_SUPPORT_VERSION}" | sort -Vr | head -n 1)" == "${FFMPEG_LIBVPL_SUPPORT_VERSION}" ]; then
    sed -i -e "s/libvpl/libmfx/g" ${PREFIX}/ffmpeg_configure_options
  fi
fi

# Configure for Linux
./configure `cat ${PREFIX}/ffmpeg_configure_options` \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --enable-gpl \
            --enable-version3 \
            --extra-libs="`cat ${PREFIX}/ffmpeg_extra_libs`" \
            --pkg-config-flags="--static" \
            --prefix=${PREFIX} | tee ${PREFIX}/configure_options 1>&2

# Build
do_make_and_make_install
do_strip ${PREFIX}/bin "ff*"


#==============================================================================
# Finalize - Copy build artifacts to output directory
#==============================================================================

# Copy library files
cp_archive ${PREFIX}/lib/*{.a,.la} ${ARTIFACT_DIR}
cp_archive ${PREFIX}/lib/pkgconfig ${ARTIFACT_DIR}
cp_archive ${PREFIX}/include ${ARTIFACT_DIR}

# Copy FFmpeg build options (for reference)
cp_archive ${PREFIX}/ffmpeg_extra_libs ${ARTIFACT_DIR}
cp_archive ${PREFIX}/ffmpeg_configure_options ${ARTIFACT_DIR}

# Copy FFmpeg binaries and configuration
cp_archive ${PREFIX}/configure_options ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/ff* ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/vainfo ${ARTIFACT_DIR}

# Copy runtime libraries
cd ${RUNTIME_LIB_DIR}
cp_archive * ${ARTIFACT_DIR}
