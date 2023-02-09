#!/bin/bash

source ./base.sh

# Build ffmpeg
FFMPEG_VERSION="${FFMPEG_VERSION:-"5.1.2"}"
INTEL_HWACCEL_LIBRARY="${INTEL_HWACCEL_LIBRARY:-""}"
if [ "${FFMPEG_VERSION}" = "master" ]; then
  git_clone "https://github.com/FFmpeg/FFmpeg.git"
  if [ -n "${INTEL_HWACCEL_LIBRARY}" ]; then
    if [ "${INTEL_HWACCEL_LIBRARY}" = "libmfx" ] || [ "${INTEL_HWACCEL_LIBRARY}" = "libvpl" ]; then
      echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-vaapi --enable-${INTEL_HWACCEL_LIBRARY}" > ${PREFIX}/ffmpeg_configure_options
    else
      echoerr 'INTEL_HWACCEL_LIBRARY must be "libmfx" or "libvpl" when FFMPEG_VERSION is master'
      exit 1
    fi
  fi
else
  download_and_unpack_file "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
  if [ -n "${INTEL_HWACCEL_LIBRARY}" ]; then
    if [ "${INTEL_HWACCEL_LIBRARY}" = "libmfx" ]; then
      echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-vaapi --enable-libmfx" > ${PREFIX}/ffmpeg_configure_options
    else
      echoerr 'INTEL_HWACCEL_LIBRARY must be "libmfx" when FFMPEG_VERSION is stable'
      exit 1
    fi
  fi
fi

# Configure
case ${TARGET_OS} in
Linux | linux)
  ./configure `cat ${PREFIX}/ffmpeg_configure_options` \
              --disable-autodetect \
              --disable-debug \
              --disable-doc \
              --enable-gpl \
              --enable-version3 \
              --extra-libs="`cat ${PREFIX}/ffmpeg_extra_libs`" \
              --pkg-config-flags="--static" \
              --prefix=${PREFIX} | tee ${PREFIX}/configure_options 1>&2
  ;;
Darwin | darwin)
  HOST_OS="macos"
  HOST_ARCH="universal"
  BUILD_TARGET=
  CROSS_PREFIX=
  ;;
Windows | windows)
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
              --prefix=${PREFIX} | tee ${PREFIX}/configure_options 1>&2
  ;;
esac

# Build
do_make_and_make_install
