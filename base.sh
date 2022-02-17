#!/bin/bash -e -c

TARGET_OS=Windows,Darwin,Linux

case ${TARGET_OS} in
Linux)
  HOST_OS="linux"
  HOST_ARCH=$(uname -m)
  BUILD_TARGET=
  CROSS_PREFIX=
  ;;
MacOS)
  HOST_OS="macos"
  HOST_ARCH="universal"
  BUILD_TARGET=
  CROSS_PREFIX=
  ;;
Windows)
  HOST_OS="linux"
  HOST_ARCH=$(uname -m)
  BUILD_TARGET="x86_64-w64-mingw32"
  CROSS_PREFIX=${BUILD_TARGET}-
  ;;
*)
  echo 'TARGET_OS must be "Windows" or "Darwin" or "Linux'
  exit 1
  ;;
esac


#
# Environment
#

WORKDIR="${HOME}/workdir"
PREFIX="${LOCAL_PREFIX}"

export PKG_CONFIG="pkg-config"
export LD_LIBRARY_PATH="${PREFIX}/lib"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export MANPATH="${PREFIX}/share/man"
export INFOPATH="${PREFIX}/share/info"
export LIBRARY_PATH="${PREFIX}/lib"
export C_INCLUDE_PATH="${PREFIX}/include"
export CPLUS_INCLUDE_PATH="${PREFIX}/include"
export PATH="${PREFIX}/bin:$PATH"

mkdir -p ${WORKDIR} ${PREFIX}/{bin,share,lib/pkgconfig,include}

FFMPEG_CONFIGURE_OPTIONS=()
FFMPEG_EXTRA_LIBS=()


#
# Helper Function
#

download_and_unpack_file () {
  cd ${WORKDIR}
  local url="$1"
  local output_name="${2:-$(basename ${url})}"
  local output_dir="$(echo ${output_name} | sed s/\.tar\.*//)"
  echo "downloading ${url} ..."
  curl -4 "${url}" --retry 50 -o "${output_name}" -L --fail
  echo "unpacking ${output_name} into ${output_dir} ..."
  mkdir -p ${output_dir}
  tar -xf "${output_name}" --strip-components 1 -C "${output_dir}"
  cd ${output_dir}
}

git_clone() {
  cd ${WORKDIR}
  local repo_url="$1"
  local branch="${2:-"master"}"
  local to_dir="$(basename ${repo_url} | sed s/\.git/_git/)"
  echo "Downloading (via git clone) ${to_dir} from $repo_url"
  git clone "${repo_url}" -b "${branch}" --depth 1 "${to_dir}"
  echo "done git cloning to ${to_dir}"
  cd ${to_dir}
}

svn_checkout() {
  cd ${WORKDIR}
  local repo_url="$1"
  local to_dir="$(basename ${repo_url})"
  echo "svn checking out to ${to_dir}"
  svn checkout "${repo_url}" "${to_dir}" --non-interactive --trust-server-cert
  cd ${to_dir}
}

mkcd () {
  mkdir -p "$1"
  cd "$1"
}

do_configure () {
  local configure_options="$1"
  local configure_name="${2:-"./configure"}"

  if [[ ! -f "${configure_name}" ]]; then
    if [ -f "bootstrap" ]; then
      ./bootstrap
    elif [ -f "bootstrap.sh" ]; then
      ./bootstrap.sh
    elif [ -f "autogen.sh" ]; then
      ./autogen.sh
    else
      autoreconf -fiv
    fi
  fi

  nice -n 5 "${configure_name}" --prefix="${PREFIX}" --host="${BUILD_TARGET}" --enable-static --disable-shared ${configure_options}
}

do_make_and_make_install () {
  local extra_make_options="$1"
  local extra_install_options="$2"
  nice make -j $(nproc) ${extra_make_options}
  nice make install ${extra_install_options}
}

do_cmake () {
  local extra_args="$1"
  local build_from_dir="${2:-"."}"
  nice -n 5 cmake -G"Unix Makefiles" "${build_from_dir}" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_TOOLCHAIN_FILE="${WORKDIR}/toolchains.cmake" $extra_args
}


