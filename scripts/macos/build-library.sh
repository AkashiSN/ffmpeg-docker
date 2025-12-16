#!/bin/bash

source ./macos/base.sh
mkdir -p ${RUNTIME_LIB_DIR}

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
# Finalize
#

cp_archive ${PREFIX}/lib/*{.a,.la} ${ARTIFACT_DIR}
cp_archive ${PREFIX}/lib/pkgconfig ${ARTIFACT_DIR}
cp_archive ${PREFIX}/include ${ARTIFACT_DIR}
echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${ARTIFACT_DIR}/${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${ARTIFACT_DIR}/${PREFIX}/ffmpeg_configure_options

echo "Library preparation completed."
