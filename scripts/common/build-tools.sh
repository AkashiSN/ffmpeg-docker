#!/bin/bash
set -eu

#
# Build Tool Wrappers
#

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
