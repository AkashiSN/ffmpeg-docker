#!/bin/bash
set -eu

#
# Windows-specific environment setup (cross-compilation)
#

# Source common scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/helpers.sh"
source "${SCRIPT_DIR}/../common/build-tools.sh"
source "${SCRIPT_DIR}/../common/versions.sh"

TARGET_OS="Windows"
HOST_OS="linux"
HOST_ARCH=$(uname -m)
BUILD_TARGET="x86_64-w64-mingw32"
CROSS_PREFIX="${BUILD_TARGET}-"

#
# Environment Variables
#

WORKDIR="${WORKDIR:-"/tmp"}"
PREFIX="${PREFIX:-"/usr/local"}"

export PKG_CONFIG="pkg-config"
export LD_LIBRARY_PATH="${PREFIX}/lib"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export MANPATH="${PREFIX}/share/man"
export INFOPATH="${PREFIX}/share/info"
export ACLOCAL_PATH="${PREFIX}/share/aclocal"
export LIBRARY_PATH="${PREFIX}/lib"
export C_INCLUDE_PATH="${PREFIX}/include"
export CPLUS_INCLUDE_PATH="${PREFIX}/include"
export CFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong ${CFLAGS:-""}"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-static-libgcc -static-libstdc++ -L${PREFIX}/lib -O2 -pipe -fstack-protector-strong ${LDFLAGS:-""}"
export STAGE_CFLAGS="-fno-semantic-interposition"
export STAGE_CXXFLAGS="${STAGE_CFLAGS}"
export PATH="${PREFIX}/bin:$PATH"

mkdir -p ${WORKDIR} ${PREFIX}/{bin,share,lib/pkgconfig,include}

FFMPEG_CONFIGURE_OPTIONS=()
FFMPEG_EXTRA_LIBS=("-lm" "-lpthread" "-lstdc++")

#
# CPU configuration
#

CPU_NUM=$(expr $(nproc) / 2)

#
# Build Tools config
#

# Cmake build toolchain
cat << EOS > ${WORKDIR}/toolchains.cmake
SET(CMAKE_SYSTEM_NAME ${TARGET_OS})
SET(CMAKE_PREFIX_PATH ${PREFIX})
SET(CMAKE_INSTALL_PREFIX ${PREFIX})
SET(CMAKE_C_COMPILER ${CROSS_PREFIX}gcc)
SET(CMAKE_CXX_COMPILER ${CROSS_PREFIX}g++)
SET(CMAKE_AR ${CROSS_PREFIX}ar)
SET(CMAKE_RANLIB ${CROSS_PREFIX}ranlib)
SET(CMAKE_RC_COMPILER ${CROSS_PREFIX}windres)
SET(CMAKE_ASM_YASM_COMPILER yasm)
EOS

# Meson build toolchain
cat << EOS > ${WORKDIR}/${BUILD_TARGET}.txt
[binaries]
c = '${CROSS_PREFIX}gcc'
cpp = '${CROSS_PREFIX}g++'
ar = '${CROSS_PREFIX}ar'
strip = '${CROSS_PREFIX}strip'
exe_wrapper = 'wine64'

[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOS
