#!/bin/bash
set -eu

echoerr () {
  echo "$@" 1>&2;
}

TARGET_OS="${TARGET_OS:-"Linux"}" # Windows,Darwin,Linux

case ${TARGET_OS} in
Linux | linux)
  TARGET_OS="Linux"
  HOST_OS="linux"
  HOST_ARCH=$(uname -m)
  BUILD_TARGET=
  CROSS_PREFIX=
  ;;
Darwin | darwin)
  if [ ! "$(uname)" = "Darwin" ]; then
    echoerr 'When TARGET_OS is "Darwin" host must be olso "Darwin"'
    exit 1
  fi
  TARGET_OS="Darwin"
  HOST_OS="macos"
  HOST_ARCH="universal"
  BUILD_TARGET=
  CROSS_PREFIX=
  ;;
Windows | windows)
  TARGET_OS="Windows"
  HOST_OS="linux"
  HOST_ARCH=$(uname -m)
  BUILD_TARGET="x86_64-w64-mingw32"
  CROSS_PREFIX=${BUILD_TARGET}-
  ;;
*)
  echoerr 'TARGET_OS must be "Windows" or "Darwin" or "Linux'
  exit 1
  ;;
esac


#
# Environment
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
export CFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread ${CFLAGS:-""}"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-static-libgcc -static-libstdc++ -L${PREFIX}/lib -O2 -pipe -fstack-protector-strong -fstack-clash-protection -Wl,-z,relro,-z,now -pthread -lm ${LDFLAGS:-""}"
export STAGE_CFLAGS="-fvisibility=hidden -fno-semantic-interposition"
export STAGE_CXXFLAGS="-fvisibility=hidden -fno-semantic-interposition"
export PATH="${PREFIX}/bin:$PATH"

mkdir -p ${WORKDIR} ${PREFIX}/{bin,share,lib/pkgconfig,include}

FFMPEG_CONFIGURE_OPTIONS=()
FFMPEG_EXTRA_LIBS=("-lm" "-lpthread" "-lstdc++")

case "$(uname)" in
Darwin)
  export CFLAGS="${CFLAGS} -Wno-error=implicit-function-declaration"
  CPU_NUM=$(expr $(getconf _NPROCESSORS_ONLN) / 2)
  ;;
Linux)
  CPU_NUM=$(expr $(nproc) / 2)
  ;;
esac


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
EOS

if [ "${TARGET_OS}" = "Windows" ]; then
  cat << EOS >> ${WORKDIR}/toolchains.cmake
SET(CMAKE_RC_COMPILER ${CROSS_PREFIX}windres)
SET(CMAKE_ASM_YASM_COMPILER yasm)
SET(CMAKE_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
SET(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "-static-libgcc -static-libstdc++ -static -O3 -s")
EOS
fi

# meson build toolchain
cat << EOS > ${WORKDIR}/x86_64-w64-mingw32.txt
[binaries]
c = 'x86_64-w64-mingw32-gcc'
cpp = 'x86_64-w64-mingw32-g++'
ar = 'x86_64-w64-mingw32-ar'
strip = 'x86_64-w64-mingw32-strip'
exe_wrapper = 'wine64'

[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOS


#
# Helper Function
#

download_and_unpack_file () {
  cd ${WORKDIR}
  local url="$1"
  local output_name="${2:-$(basename ${url})}"
  local output_dir="$(echo ${output_name} | sed s/\.tar\.*//)"
  if [ ! -e "${output_name}" ]; then
    echoerr -n "downloading ${url} ..."
    curl -4 "${url}" --retry 50 -o "${output_name}" -L -s --fail
    echoerr "done."
  fi
  echoerr -n "unpacking ${output_name} into ${output_dir} ..."
  rm -rf "${output_dir}"
  mkdir -p "${output_dir}"
  tar -xf "${output_name}" --strip-components 1 -C "${output_dir}"
  echoerr "done."
  cd ${output_dir}
}

git_clone() {
  cd ${WORKDIR}
  local repo_url="$1"
  local branch="${2:-"master"}"
  local version="${3:-""}"
  local package="$(basename ${repo_url} | sed s/\.git//)"
  if [ -n "${version}" ]; then
    local to_dir="${package}-${version}"
  else
    local to_dir="${package}-$(echo ${branch} | sed s/^v//)"
  fi
  echoerr -n "downloading (via git clone) ${to_dir} from $repo_url ..."
  rm -rf "${to_dir}"
  git clone -c advice.detachedHead=false "${repo_url}" -b "${branch}" --depth 1 "${to_dir}"
  echoerr "done."
  cd ${to_dir}
}

svn_checkout() {
  cd ${WORKDIR}
  local repo_url="$1"
  local to_dir="$(basename ${repo_url})"
  echoerr -n "svn checking out to ${to_dir} ..."
  svn checkout "${repo_url}" "${to_dir}" --non-interactive --trust-server-cert
  cd ${to_dir}
  echoerr "done."
}

mkcd () {
  rm -rf "$1"
  mkdir -p "$1"
  cd "$1"
}

cp_archive () {
  cp --archive --parents --no-dereference $@
}

do_configure () {
  local configure_options="${1:-""}"
  local configure_name="${2:-"./configure"}"

  if [[ ! -f "${configure_name}" ]]; then
    autoreconf -fiv
  fi

  "${configure_name}" --prefix="${PREFIX}" --host="${BUILD_TARGET}" ${configure_options} 1>&2
}

do_make_and_make_install () {
  local overwrite_cpu_num="${1:-${CPU_NUM}}"
  local extra_make_options="${2:-""}"
  local extra_install_options="${3:-""}"
  make -j ${overwrite_cpu_num} ${extra_make_options}
  make install ${extra_install_options}
}

do_cmake () {
  local extra_args="${1:-""}"
  local build_from_dir="${2:-"."}"
  cmake -G"Unix Makefiles" "${build_from_dir}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_TOOLCHAIN_FILE="${WORKDIR}/toolchains.cmake" $extra_args 1>&2
}

do_meson () {
  local extra_args="${1:-""}"
  local build_from_dir="${2:-"."}"
  meson --buildtype=release --prefix="${PREFIX}" --bindir=bin --libdir=lib $build_from_dir $extra_args 1>&2
}

do_ninja_and_ninja_install () {
  ninja
  ninja install
}

gen_implib () {
  local in="$1"
  local out="$2"

  local tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT
  pushd "$tmpdir"

  set -x
  python3 /opt/implib/implib-gen.py --target x86_64-linux-gnu --dlopen --lazy-load --verbose "$in"
  ${CROSS_PREFIX}gcc $CFLAGS $STAGE_CFLAGS -DIMPLIB_HIDDEN_SHIMS -c *.tramp.S *.init.c
  ${CROSS_PREFIX}ar -rcs "$out" *.tramp.o *.init.o
  set +x

  popd
}
