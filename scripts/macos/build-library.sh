#!/bin/bash
set -euo pipefail

#
# macOS Library Build Script
# 現在は空ですが、将来的にライブラリビルドを追加できる構造
#

# 環境変数の読み込み
WORKDIR="${WORKDIR:-"/tmp/ffmpeg-build"}"
LOCAL="${LOCAL:-"$WORKDIR/local"}"
PREFIX="${PREFIX:-"${LOCAL}"}"

echo "macOS library build script"
echo "Currently no additional libraries are built."
echo "This structure allows for future library additions."

# 将来的にここにライブラリビルドを追加可能
# 例:
# - x264
# - x265
# - libvpx
# など

# FFMPEG_CONFIGURE_OPTIONS配列を初期化
FFMPEG_CONFIGURE_OPTIONS=()
FFMPEG_EXTRA_LIBS=()

# 設定を保存（将来的に使用）
mkdir -p ${PREFIX}
echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options

echo "Library preparation completed."
