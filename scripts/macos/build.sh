#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${SCRIPT_DIR}/base.sh


#==============================================================================
# Build Libraries
#==============================================================================

#
# Video
#

# Build libvpx
LIBVPX_REPO="https://chromium.googlesource.com/webm/libvpx.git"
LIBVPX_TAG_PREFIX="v"
LIBVPX_VERSION="1.15.2" # get_latest_tag ${LIBVPX_REPO} ${LIBVPX_TAG_PREFIX}
git_clone ${LIBVPX_REPO} ${LIBVPX_TAG_PREFIX}${LIBVPX_VERSION}
./configure --prefix="${PREFIX}" --disable-shared --enable-static --enable-pic --disable-examples \
  --disable-tools --disable-docs --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvpx")

# Build x264
download_and_unpack_file "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2"
do_configure "--cross-prefix=${CROSS_PREFIX} --enable-static --enable-pic --disable-cli --disable-lavf --disable-swscale"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx264")

# Build x265
X265_VERSION="master"
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

libtool -static -o libx265.a libx265_main.a libx265_main10.a libx265_main12.a

make install
cat <<EOS > ${PKG_CONFIG_PATH}/x265.pc
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265 (HEVC) encoder library
Version: 5.0

Libs: -L\${libdir} -lx265 -lpthread -lstdc++
Cflags: -I\${includedir}
EOS
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx265")

# Build libaom
LIBAOM_REPO="https://aomedia.googlesource.com/aom.git"
LIBAOM_TAG_PREFIX="v"
LIBAOM_VERSION="3.13.1" # get_latest_tag ${LIBAOM_REPO} ${LIBAOM_TAG_PREFIX}
git_clone ${LIBAOM_REPO} ${LIBAOM_TAG_PREFIX}${LIBAOM_VERSION}
mkcd _build
do_cmake "-DBUILD_SHARED_LIBS=0 -DENABLE_DOCS=0 -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libaom")


#
# Audio
#

# Build opus
OPUS_REPO="https://github.com/xiph/opus.git"
OPUS_TAG_PREFIX="v"
OPUS_VERSION="1.6" # get_latest_tag ${OPUS_REPO} ${OPUS_TAG_PREFIX}
git_clone ${OPUS_REPO} ${OPUS_TAG_PREFIX}${OPUS_VERSION}
mkcd build
do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0" ..
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopus")

# Build mp3lame
svn_checkout "https://svn.code.sf.net/p/lame/svn/trunk/lame"
do_configure "--disable-shared --enable-static --enable-nasm --disable-decoder --disable-gtktest --disable-cpml --disable-frontend"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libmp3lame")


#------------------------------------------------------------------------------
# Prepare FFmpeg Build Options
#------------------------------------------------------------------------------

# Write library options to files for FFmpeg configure
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options

#==============================================================================
# Build FFmpeg
#==============================================================================

# Build ffmpeg
FFMPEG_VERSION="${FFMPEG_VERSION:-"8.0"}"
git_clone "https://github.com/FFmpeg/FFmpeg.git" n${FFMPEG_VERSION}

# Configure for macOS
./configure `cat ${PREFIX}/ffmpeg_configure_options` \
            --arch=${HOST_ARCH} \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --enable-gpl \
            --enable-version3 \
            --enable-videotoolbox \
            --enable-neon \
            --pkg-config-flags="--static" \
            --prefix=${PREFIX} | tee ${PREFIX}/configure_options 1>&2

# Build
do_make_and_make_install
do_strip ${PREFIX}/bin "ff*"


#==============================================================================
# Finalize - Copy build artifacts to output directory
#==============================================================================

# Copy FFmpeg build options (for reference)
cp_archive ${PREFIX}/ffmpeg_configure_options ${ARTIFACT_DIR}

# Copy FFmpeg binaries and configuration
cp_archive ${PREFIX}/configure_options ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/ff* ${ARTIFACT_DIR}
