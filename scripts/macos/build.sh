#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${SCRIPT_DIR}/base.sh

rm -rf ${ARTIFACT_DIR}
mkdir -p ${RUNTIME_LIB_DIR}
mkdir -p ${ARTIFACT_DIR}


#==============================================================================
# Build Libraries
#==============================================================================

echo "macOS library build script"
echo "Currently no additional libraries are built."
echo "This structure allows for future library additions."

# 将来的にここにライブラリビルドを追加可能
# 例:
# - x264
# - x265
# - libvpx
# など


#------------------------------------------------------------------------------
# Prepare FFmpeg Build Options
#------------------------------------------------------------------------------

# Write library options to files for FFmpeg configure
# echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${PREFIX}/ffmpeg_extra_libs
# echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options
touch ${PREFIX}/ffmpeg_extra_libs
touch ${PREFIX}/ffmpeg_configure_options


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
# cp_archive ${PREFIX}/lib/*{.a,.la} ${ARTIFACT_DIR}
# cp_archive ${PREFIX}/lib/pkgconfig ${ARTIFACT_DIR}
# cp_archive ${PREFIX}/include ${ARTIFACT_DIR}

# Copy FFmpeg build options (for reference)
cp_archive ${PREFIX}/ffmpeg_extra_libs ${ARTIFACT_DIR}
cp_archive ${PREFIX}/ffmpeg_configure_options ${ARTIFACT_DIR}

# Copy FFmpeg binaries and configuration
cp_archive ${PREFIX}/configure_options ${ARTIFACT_DIR}
cp_archive ${PREFIX}/bin/ff* ${ARTIFACT_DIR}
