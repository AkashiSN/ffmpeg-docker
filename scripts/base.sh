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
export LIBRARY_PATH="${PREFIX}/lib"
export C_INCLUDE_PATH="${PREFIX}/include"
export CPLUS_INCLUDE_PATH="${PREFIX}/include"
export LDFLAGS="-L${PREFIX}/lib ${LDFLAGS:-""}"
export CFLAGS="-I${PREFIX}/include ${CFLAGS:-""}"
export CXXFLAGS="${CFLAGS}"
export PATH="${PREFIX}/bin:$PATH"

mkdir -p ${WORKDIR} ${PREFIX}/{bin,share,lib/pkgconfig,include}

FFMPEG_CONFIGURE_OPTIONS=()
FFMPEG_EXTRA_LIBS=()

case "$(uname)" in
Darwin)
  export CFLAGS="${CFLAGS} -Wno-error=implicit-function-declaration"
  CPU_NUM=$(getconf _NPROCESSORS_ONLN)
  ;;
Linux)
  CPU_NUM=$(nproc)
  ;;
esac


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
  local to_dir="$(basename ${repo_url} | sed s/\.git//)-${branch}"
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

do_configure () {
  local configure_options="${1:-""}"
  local configure_name="${2:-"./configure"}"

  if [[ ! -f "${configure_name}" ]]; then
    if [ -f "autogen.sh" ]; then
      export NOCONFIGURE=yes
      ./autogen.sh
      unset NOCONFIGURE
    elif [ -f "bootstrap" ]; then
      ./bootstrap
    elif [ -f "bootstrap.sh" ]; then
      ./bootstrap.sh
    else
      autoreconf -fiv
      automake --add-missing
    fi
  fi

  "${configure_name}" --prefix="${PREFIX}" --host="${BUILD_TARGET}" --enable-static --disable-shared ${configure_options} 1>&2
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
  cmake -G"Unix Makefiles" "${build_from_dir}" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_TOOLCHAIN_FILE="${WORKDIR}/toolchains.cmake" $extra_args
}


