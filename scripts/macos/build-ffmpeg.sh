#!/bin/bash
set -euo pipefail

#
# macOS FFmpeg Build Script
# Apple Silicon向けFFmpeg最小構成ビルド
# VideoToolboxハードウェアアクセラレーションとネイティブコーデックのみを有効化
#

# 環境変数の設定
WORKDIR="${WORKDIR:-"/tmp/ffmpeg-build"}"
LOCAL="${LOCAL:-"$WORKDIR/local"}"
SRC="${SRC:-"$LOCAL/src"}"
PREFIX="${PREFIX:-"${LOCAL}"}"
NUM_PARALLEL_BUILDS=$(sysctl -n hw.ncpu)
FFMPEG_VERSION="${FFMPEG_VERSION:-"8.0"}"

# Apple Silicon (arm64) チェック
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Error: This script is for Apple Silicon (arm64) only"
  exit 1
fi

# ビルド環境の設定
export PATH=${LOCAL}/bin:$PATH
export CC=clang
export PKG_CONFIG_PATH="${LOCAL}/lib/pkgconfig"
export ARCH=arm64
export LDFLAGS="${LDFLAGS:-""}"
export CFLAGS="${CFLAGS:-""}"

# ビルドディレクトリの初期化
echo "Setting up build directories..."
mkdir -p "${LOCAL}" "${SRC}"

# FFmpegソースコードのダウンロード
echo ""
echo "Downloading FFmpeg ${FFMPEG_VERSION} source..."
if [[ ! -d "${SRC}/ffmpeg" ]]; then
  cd "${SRC}"
  git clone --depth 1 -b "n${FFMPEG_VERSION}" https://github.com/FFmpeg/FFmpeg ffmpeg
  echo "Download completed."
else
  echo "FFmpeg source already exists, skipping download."
fi

# FFmpegのビルド
echo ""
echo "Building FFmpeg..."
cd "${SRC}/ffmpeg"

# 最小構成でビルド: VideoToolboxとネイティブコーデックのみ
echo "Configuring FFmpeg..."
./configure \
  --prefix=${PREFIX} \
  --arch=arm64 \
  --cc=/usr/bin/clang \
  --enable-static \
  --disable-shared \
  --enable-videotoolbox \
  --enable-neon \
  --disable-ffplay \
  --disable-doc \
  --disable-debug \
  --pkg-config=false

echo ""
echo "Compiling (this may take a while)..."
start_time="$(date -u +%s)"
make -j ${NUM_PARALLEL_BUILDS}
end_time="$(date -u +%s)"
elapsed="$(($end_time-$start_time))"

echo ""
echo "Installing..."
make install

echo ""
echo "Build completed in ${elapsed}s"
echo ""
echo "Binaries installed at:"
echo "  ${PREFIX}/bin/ffmpeg"
echo "  ${PREFIX}/bin/ffprobe"
