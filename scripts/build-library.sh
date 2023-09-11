#!/bin/bash

source ./base.sh
mkdir -p ${RUNTIME_LIB_DIR}


#
# Common library
#

# Build xorg-macros
XORG_MACROS_VERSION="1.20.0"
XORG_MACROS_TAG="util-macros-${XORG_MACROS_VERSION}"
git_clone "https://gitlab.freedesktop.org/xorg/util/macros.git" ${XORG_MACROS_TAG} ${XORG_MACROS_VERSION}
do_configure
do_make_and_make_install

# Build zlib
ZLIB_VERSION="1.3"
git_clone https://github.com/madler/zlib.git "v${ZLIB_VERSION}"
CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib ./configure --prefix=${PREFIX} --static
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-zlib")

# Build bzip2
BZIP2_VERSION="1.0.8"
git_clone "https://gitlab.com/bzip2/bzip2.git" "bzip2-${BZIP2_VERSION}" "${BZIP2_VERSION}"
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
LZMA_VERSION="5.4.4"
git_clone "https://github.com/tukaani-project/xz.git" v${LZMA_VERSION}
./autogen.sh --no-po4a --no-doxygen
do_configure "--enable-static --disable-shared --with-pic --disable-symbol-versions
              --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-lzma")

# Build Nettle (for gmp,gnutls)
NETTLE_VERSION="3.9.1"
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/nettle/nettle-${NETTLE_VERSION}.tar.gz"
do_configure "--enable-static --disable-shared --libdir=${PREFIX}/lib --enable-mini-gmp --disable-openssl --disable-documentation"
do_make_and_make_install

# Build GMP
GMP_VERSION="6.3.0"
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/gmp/gmp-${GMP_VERSION}.tar.xz"
do_configure "--enable-static --disable-shared --with-pic"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gmp")

# Build libtasn1 (for gnutls)
LIBTASN1_VERSION="4.19.0"
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz"
do_configure "--enable-static --disable-shared"
do_make_and_make_install

# Build libunistring (for gnutls)
LIBUNISTRING_VERSION="1.1"
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libunistring/libunistring-${LIBUNISTRING_VERSION}.tar.xz"
do_configure "--enable-static --disable-shared"
do_make_and_make_install

# Build libiconv
ICONV_VERSION="1.17"
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libiconv/libiconv-${ICONV_VERSION}.tar.gz"
do_configure "--enable-static --disable-shared --with-pic --enable-extra-encodings"
make install-lib
FFMPEG_CONFIGURE_OPTIONS+=("--enable-iconv")

# Build GnuTLS
GNUTLS_MAJAR_VERSION="3.8"
GNUTLS_VERSION="${GNUTLS_MAJAR_VERSION}.1"
download_and_unpack_file "https://www.gnupg.org/ftp/gcrypt/gnutls/v${GNUTLS_MAJAR_VERSION}/gnutls-${GNUTLS_VERSION}.tar.xz"
do_configure "--enable-static --disable-shared --with-pic --disable-tests --disable-doc --disable-tools --without-p11-kit"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gnutls")

# Build SRT
SRT_VERSION="1.5.3"
git_clone "https://github.com/Haivision/srt.git" v${SRT_VERSION}
mkcd build
do_cmake "-DENABLE_SHARED=0 -DENABLE_APPS=0 -DENABLE_CXX_DEPS=1 -DUSE_STATIC_LIBSTDCXX=1
          -DENABLE_ENCRYPTION=1 -DUSE_ENCLIB=gnutls" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libsrt")

if [ "${TARGET_OS}" = "Linux" ]; then
  # Build libpciaccess
  LIBPCIACCESS_VERSION="0.17"
  LIBPCIACCESS_TAG="libpciaccess-${LIBPCIACCESS_VERSION}"
  git_clone "https://gitlab.freedesktop.org/xorg/lib/libpciaccess.git" ${LIBPCIACCESS_TAG} ${LIBPCIACCESS_VERSION}
  do_configure "--enable-shared --disable-static --with-pic --with-zlib"
  do_make_and_make_install
  gen_implib ${PREFIX}/lib/{libpciaccess.so.0,libpciaccess.a}
  cp_archive ${PREFIX}/lib/libpciaccess.so* ${RUNTIME_LIB_DIR}
  rm ${PREFIX}/lib/libpciaccess{.so*,.la}
fi

#
# Image
#

# Build libpng (for libwebp)
LIBPNG_VERSION="1.6.40"
git_clone "https://github.com/glennrp/libpng.git" "v${LIBPNG_VERSION}"
do_configure "--enable-static --disable-shared --with-pic"
do_make_and_make_install

# Build libjpeg (for libwebp)
LIBJPEG_VERSION="9e"
download_and_unpack_file "http://www.ijg.org/files/jpegsrc.v${LIBJPEG_VERSION}.tar.gz"
do_configure "--enable-static --disable-shared --with-pic"
do_make_and_make_install

# Build openjpeg
OPENJPEG_VERSION="2.5.0"
git_clone "https://github.com/uclouvain/openjpeg.git" "v${OPENJPEG_VERSION}"
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DDBUILD_PKGCONFIG_FILES=1 -DBUILD_CODEC=0 -DWITH_ASTYLE=0 -DBUILD_TESTING=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopenjpeg")

# Build libwebp
LIBWEBP_VERSION="1.3.1"
git_clone "https://chromium.googlesource.com/webm/libwebp.git" "v${LIBWEBP_VERSION}"
do_configure "--enable-static --disable-shared --with-pic --enable-libwebpmux --enable-png --enable-jpeg
              --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-tiff --disable-gif"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libwebp")


#
# Video
#

# Build libvpx
LIBVPX_VERSION="1.13.0"
git_clone "https://chromium.googlesource.com/webm/libvpx" v${LIBVPX_VERSION}
if [ "${TARGET_OS}" = "Windows" ]; then
  CROSS=${CROSS_PREFIX} ./configure --prefix="${PREFIX}" --target=x86_64-win64-gcc --disable-shared \
                          --enable-static --enable-pic --disable-examples --disable-tools --disable-docs \
                          --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
else
  ./configure --prefix="${PREFIX}" --disable-shared --enable-static --enable-pic --disable-examples \
    --disable-tools --disable-docs --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
fi
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
LIBAOM_VERSION="3.7.0"
git_clone "https://aomedia.googlesource.com/aom" v${LIBAOM_VERSION}
mkcd _build
do_cmake "-DAOM_TARGET_CPU=x86_64 -DBUILD_SHARED_LIBS=0 -DENABLE_NASM=1 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libaom")

# Build vmaf
VMAF_VERSION="2.3.1"
git_clone "https://github.com/Netflix/vmaf.git" v${VMAF_VERSION}
mkcd build
if [ "${TARGET_OS}" = "Windows" ]; then
  do_meson "--default-library=static -Denable_tests=false -Denable_docs=false --cross-file=${WORKDIR}/${BUILD_TARGET}.txt" ../libvmaf
else
  do_meson "--default-library=static -Denable_tests=false -Denable_docs=false" ../libvmaf
fi
do_ninja_and_ninja_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvmaf")


#
# Audio
#

# Build opus
OPUS_VERSION="1.4"
git_clone "https://github.com/xiph/opus.git" v${OPUS_VERSION}
mkcd build
if [ "${TARGET_OS}" = "Windows" ]; then
  do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 -DOPUS_STACK_PROTECTOR=0 -DOPUS_FORTIFY_SOURCE=0" ..
else
  do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0" ..
fi
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopus")

# Build libogg, for vorbis
OGG_VERSION="1.3.5"
git_clone "https://github.com/xiph/ogg.git" v${OGG_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DINSTALL_DOCS=0 -DBUILD_TESTING=0" ..
do_make_and_make_install

# Build vorbis
VORBIS_VERSION="1.3.7"
git_clone "https://github.com/xiph/vorbis.git" v${VORBIS_VERSION}
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
if [ "${TARGET_OS}" = "Windows" ]; then
  sed -i -e "s%Libs: \(.*\)%Libs: \1 -lpthread%g" ${PKG_CONFIG_PATH}/freetype2.pc
fi
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
if [ "${TARGET_OS}" = "Windows" ]; then
  do_meson "--default-library=static -Dfreetype=enabled -Dicu=disabled -Dtests=disabled --cross-file=${WORKDIR}/${BUILD_TARGET}.txt" ..
else
  do_meson "--default-library=static -Dfreetype=enabled -Dicu=disabled -Dtests=disabled" ..
fi
do_ninja_and_ninja_install

# Build libass
LIBASS_VERSION="0.17.1"
git_clone "https://github.com/libass/libass.git" ${LIBASS_VERSION}
do_configure "--disable-shared --enable-static"
do_make_and_make_install
if [ "${TARGET_OS}" = "Windows" ]; then
  sed -i -e "s%Libs.private: \(.*\)%Libs.private: \1 -lgdi32 -ldwrite%g" ${PKG_CONFIG_PATH}/libass.pc
fi
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
SDL_VERSION="2.28.3"
download_and_unpack_file "https://www.libsdl.org/release/SDL2-${SDL_VERSION}.tar.gz"
do_configure "--disable-shared --enable-static"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-sdl2")


#
# HWAccel
#

# Build NVcodec
NVCODEC_VERSION="n12.0.16.0"
git_clone "https://github.com/FFmpeg/nv-codec-headers" ${NVCODEC_VERSION}
make install "PREFIX=${PREFIX}"
FFMPEG_CONFIGURE_OPTIONS+=("--enable-cuda-llvm" "--enable-ffnvcodec" "--enable-cuvid" "--enable-nvdec" "--enable-nvenc")

if [ "${TARGET_OS}" = "Linux" ]; then
  # Build libdrm
  LIBDRM_VERSION="2.4.116"
  LIBDRM_TAG="libdrm-${LIBDRM_VERSION}"
  git_clone "https://gitlab.freedesktop.org/mesa/drm.git" ${LIBDRM_TAG} ${LIBDRM_VERSION}
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

  # Build libva
  LIBVA_VERSION="2.19.0"
  git_clone "https://github.com/intel/libva.git" ${LIBVA_VERSION}
  do_configure "--enable-shared --disable-static --with-pic --disable-docs --enable-drm
                --disable-x11 --disable-glx --disable-wayland --sysconfdir=/etc"
  do_make_and_make_install
  gen_implib ${PREFIX}/lib/{libva.so.2,libva.a}
  gen_implib ${PREFIX}/lib/{libva-drm.so.2,libva-drm.a}
  cp_archive ${PREFIX}/lib/libva{,-drm}.so* ${RUNTIME_LIB_DIR}
  rm ${PREFIX}/lib/libva{,-drm}{.so*,.la}
  FFMPEG_CONFIGURE_OPTIONS+=("--enable-vaapi")

  # Build libva-utils
  LIBVA_UTILS_VERSION="2.19.0"
  git_clone "https://github.com/intel/libva-utils.git" ${LIBVA_UTILS_VERSION}
  do_configure "--with-pic --enable-drm --disable-x11"
  do_make_and_make_install
  cp_archive ${PREFIX}/bin/vainfo ${ARTIFACT_DIR}

  # Build gmmlib
  GMMLIB_VERSION="22.3.11"
  GMMLIB_TAG="intel-gmmlib-${GMMLIB_VERSION}"
  git_clone "https://github.com/intel/gmmlib.git" ${GMMLIB_TAG} ${GMMLIB_VERSION}
  mkcd build
  do_cmake ..
  do_make_and_make_install
  cp_archive ${PREFIX}/lib/libigdgmm.so* ${RUNTIME_LIB_DIR}

  # Build media-driver
  MEDIA_DRIVER_VERSION="23.3.3"
  MEDIA_DRIVER_TAG="intel-media-${MEDIA_DRIVER_VERSION}"
  git_clone "https://github.com/intel/media-driver.git" ${MEDIA_DRIVER_TAG} ${MEDIA_DRIVER_VERSION}
  mkcd build
  do_cmake "-DENABLE_KERNELS=1 -DENABLE_NONFREE_KERNELS=1 -DENABLE_PRODUCTION_KMD=1" ..
  do_make_and_make_install
  cp_archive ${PREFIX}/lib/dri ${RUNTIME_LIB_DIR}
  cp_archive ${PREFIX}/lib/libigfxcmrt.so* ${RUNTIME_LIB_DIR}

  # Build intel-vaapi-driver
  INTEL_VAAPI_DRIVER_VERSION="2.4.1"
  git_clone "https://github.com/intel/intel-vaapi-driver" ${INTEL_VAAPI_DRIVER_VERSION}
  mkcd build
  do_meson "-Ddriverdir=${PREFIX}/lib/dri" ..
  do_ninja_and_ninja_install
  cp_archive ${PREFIX}/lib/dri ${RUNTIME_LIB_DIR}

  # Build oneVPL gpu runtime
  ONEVPL_INTEL_GPU_VERSION="23.3.3"
  ONEVPL_INTEL_GPU_TAG="intel-onevpl-${ONEVPL_INTEL_GPU_VERSION}"
  git_clone "https://github.com/oneapi-src/oneVPL-intel-gpu.git" ${ONEVPL_INTEL_GPU_TAG} ${ONEVPL_INTEL_GPU_VERSION}
  mkcd build
  do_cmake "-DBUILD_RUNTIME=1 -DBUILD_TESTS=0" ..
  do_make_and_make_install
  cp_archive ${PREFIX}/lib/libmfx-gen ${RUNTIME_LIB_DIR}
  cp_archive ${PREFIX}/lib/libmfx-gen.so* ${RUNTIME_LIB_DIR}

  # Build MediaSDK
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
fi

# Build oneVPL
ONEVPL_VERSION="2023.3.1"
git_clone "https://github.com/oneapi-src/oneVPL.git" v${ONEVPL_VERSION}
mkcd build
do_cmake "-DBUILD_DISPATCHER=1 -DBUILD_DEV=1 -DBUILD_PREVIEW=0 -DBUILD_TOOLS=0
          -DBUILD_TOOLS_ONEVPL_EXPERIMENTAL=0 -DINSTALL_EXAMPLE_CODE=0 -DBUILD_SHARED_LIBS=0 -DBUILD_TESTS=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvpl")

if [ "${TARGET_OS}" = "Windows" ]; then
  # Build MFX_dispatch
  git_clone "https://github.com/lu-zero/mfx_dispatch.git"
  do_configure "--disable-shared --enable-static"
  do_make_and_make_install

  # Other hwaccel
  FFMPEG_CONFIGURE_OPTIONS+=("--enable-d3d11va" "--enable-dxva2")
fi


#
# Finalize
#

cp_archive ${PREFIX}/lib/*{.a,.la} ${ARTIFACT_DIR}
cp_archive ${PREFIX}/lib/pkgconfig ${ARTIFACT_DIR}
cp_archive ${PREFIX}/include ${ARTIFACT_DIR}
echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${ARTIFACT_DIR}/${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${ARTIFACT_DIR}/${PREFIX}/ffmpeg_configure_options