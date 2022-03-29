#!/bin/bash

source ./base.sh

# Build ffmpeg
FFMPEG_VERSION="${FFMPEG_VERSION:-"5.0"}"
download_and_unpack_file "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
case ${TARGET_OS} in
Linux)
  ./configure `cat ${PREFIX}/ffmpeg_configure_options` \
              --disable-autodetect \
              --disable-debug \
              --disable-doc \
              --enable-gpl \
              --enable-version3 \
              --extra-libs="`cat ${PREFIX}/ffmpeg_extra_libs`" \
              --pkg-config-flags="--static" \
              --prefix=${PREFIX} > ${PREFIX}/configure_options
  ;;
MacOS)
  HOST_OS="macos"
  HOST_ARCH="universal"
  BUILD_TARGET=
  CROSS_PREFIX=
  ;;
Windows)
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
              --extra-libs="-static -static-libgcc -static-libstdc++ -Wl,-Bstatic `cat ${PREFIX}/ffmpeg_extra_libs`" \
              --extra-cflags="--static" \
              --target-os="mingw64" \
              --pkg-config="pkg-config" \
              --pkg-config-flags="--static" \
              --prefix=${PREFIX} > ${PREFIX}/configure_options
  ;;
esac

do_make_and_make_install
