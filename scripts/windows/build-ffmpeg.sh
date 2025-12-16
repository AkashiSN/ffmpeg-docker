#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${SCRIPT_DIR}/base.sh

rm -r ${ARTIFACT_DIR}
mkdir -p ${ARTIFACT_DIR}

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

# Configure for Windows
./configure `cat ${PREFIX}/ffmpeg_configure_options` \
            --arch="x86_64" \
            --cross-prefix="${CROSS_PREFIX}" \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --disable-w32threads \
            --enable-cross-compile \
            --enable-gpl \
            --enable-version3 \
            --extra-libs="-static -Wl,-Bstatic `cat ${PREFIX}/ffmpeg_extra_libs`" \
            --extra-cflags="--static" \
            --target-os="mingw64" \
            --pkg-config="pkg-config" \
            --pkg-config-flags="--static" \
            --prefix=${PREFIX} | tee ${PREFIX}/configure_options 1>&2

# Build
do_make_and_make_install
do_strip ${PREFIX}/bin "ff*"


#
# Finalize
#

cp_archive ${PREFIX}/configure_options ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/ff* ${ARTIFACT_DIR}
