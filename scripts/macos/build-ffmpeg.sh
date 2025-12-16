#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${SCRIPT_DIR}/base.sh

rm -r ${ARTIFACT_DIR}
mkdir -p ${ARTIFACT_DIR}

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

cp_archive ${PREFIX}/configure_options ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/ff* ${ARTIFACT_DIR}
