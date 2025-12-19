#!/bin/bash
set -eu

#
# macOS-specific environment setup
#

# Source common scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/helpers.sh"
source "${SCRIPT_DIR}/../common/build-tools.sh"
source "${SCRIPT_DIR}/../common/versions.sh"

TARGET_OS="Darwin"
HOST_OS="macos"
BUILD_TARGET=
CROSS_PREFIX=

#
# Environment Variables
#

WORKDIR="${WORKDIR:-$(mktemp -d)}"
PREFIX="${PREFIX:-"/opt/ffmpeg"}"
ARTIFACT_DIR="${ARTIFACT_DIR:-"/tmp/dist"}"
RUNTIME_LIB_DIR="${RUNTIME_LIB_DIR:-"$ARTIFACT_DIR/runtime"}"

export CC="clang"
export CXX="clang++"
export PKG_CONFIG="pkg-config"
export LD_LIBRARY_PATH="${PREFIX}/lib"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export MANPATH="${PREFIX}/share/man"
export INFOPATH="${PREFIX}/share/info"
export ACLOCAL_PATH="${PREFIX}/share/aclocal"
export LIBRARY_PATH="${PREFIX}/lib"
export C_INCLUDE_PATH="${PREFIX}/include"
export CPLUS_INCLUDE_PATH="${PREFIX}/include"
export PATH="${PREFIX}/bin:$PATH"

# Detect architecture
if [[ "$(uname -m)" == "arm64" ]]; then
  HOST_ARCH="arm64"
else
  HOST_ARCH="x86_64"
fi

rm -rf ${ARTIFACT_DIR}
rm -rf ${PREFIX}/{bin,include,lib,share}
rm -rf ${PREFIX}/{configure_options,ffmpeg_configure_options,ffmpeg_extra_libs}

mkdir -p ${ARTIFACT_DIR}
mkdir -p ${WORKDIR}
mkdir -p ${RUNTIME_LIB_DIR}
mkdir -p ${PREFIX}/{bin,share,lib/pkgconfig,include}

FFMPEG_CONFIGURE_OPTIONS=()
FFMPEG_EXTRA_LIBS=()

#
# CPU configuration
#

CPU_NUM=$(expr $(getconf _NPROCESSORS_ONLN) / 2)

#
# Build Tools config
#

# Cmake build toolchain
cat << EOS > ${WORKDIR}/toolchains.cmake
SET(CMAKE_POLICY_VERSION_MINIMUM 3.5)
SET(CMAKE_SYSTEM_NAME ${TARGET_OS})
SET(CMAKE_PREFIX_PATH ${PREFIX})
SET(CMAKE_INSTALL_PREFIX ${PREFIX})
SET(CMAKE_C_COMPILER ${CROSS_PREFIX}${CC})
SET(CMAKE_CXX_COMPILER ${CROSS_PREFIX}${CXX})
SET(CMAKE_AR ${CROSS_PREFIX}ar)
SET(CMAKE_RANLIB ${CROSS_PREFIX}ranlib)
EOS
