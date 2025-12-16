#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${SCRIPT_DIR}/base.sh

rm -rf ${ARTIFACT_DIR}
mkdir -p ${RUNTIME_LIB_DIR}
mkdir -p ${ARTIFACT_DIR}


#
# Build Libraries
#

echo "macOS library build script"
echo "Currently no additional libraries are built."
echo "This structure allows for future library additions."

# 将来的にここにライブラリビルドを追加可能
# 例:
# - x264
# - x265
# - libvpx
# など


#
# Build FFmpeg
#

# Build ffmpeg
FFMPEG_VERSION="${FFMPEG_VERSION:-"8.0"}"
git_clone "https://github.com/FFmpeg/FFmpeg.git" n${FFMPEG_VERSION}

# Configure for macOS
./configure `cat ${PREFIX}/ffmpeg_configure_options` \
            --arch=${HOST_ARCH} \
            --cc=/usr/bin/clang \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --enable-gpl \
            --enable-version3 \
            --enable-videotoolbox \
            --enable-neon \
            --extra-libs="`cat ${PREFIX}/ffmpeg_extra_libs`" \
            --pkg-config-flags="--static" \
            --prefix=${PREFIX} | tee ${PREFIX}/configure_options 1>&2

# Build
do_make_and_make_install
do_strip ${PREFIX}/bin "ff*"


#
# Finalize
#

cp_archive ${PREFIX}/lib/*{.a,.la} ${ARTIFACT_DIR}
cp_archive ${PREFIX}/lib/pkgconfig ${ARTIFACT_DIR}
cp_archive ${PREFIX}/include ${ARTIFACT_DIR}
echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${ARTIFACT_DIR}/${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${ARTIFACT_DIR}/${PREFIX}/ffmpeg_configure_options
cp_archive ${PREFIX}/configure_options ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/ff* ${ARTIFACT_DIR}
