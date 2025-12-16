#!/bin/bash
set -eu

#
# Helper Functions
#

echoerr () {
  echo "$@" 1>&2;
}

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

get_latest_version() {
  local url=$1
  local prefix=$2
  local major_version="${3:-""}"

  if [ -n "${major_version}" ]; then
    local url="${url}/${major_version}"
  fi

  local version_pattern="${prefix}\K[0-9]+(\.[0-9]+)+"

  local html_content=$(curl -sL "$url")

  local latest_version=$(echo "$html_content" | \
      grep -oP $version_pattern | \
      sort -V | tail -n1)

  echo "$latest_version"
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

get_latest_tag() {
  local repo_url=$1
  local prefix="${2:-""}"

  local version_pattern="^${prefix}\K[0-9]+(\.[0-9]+)+$"

  latest_tag=$(git ls-remote --tags "$repo_url" | awk -F/ '{print $NF}' | \
      grep -oP "$version_pattern" | \
      sort -V | tail -n1)

  echo "$latest_tag"
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

do_strip () {
  local target_dir="$1"
  local file_pattern="$2"

  if [[ $HOST_OS == "macos" ]]; then
    # BSD find doesn't support -executable, use -perm instead
    # -perm +111 matches files with execute permission for user, group, or other
    /usr/bin/find ${target_dir} -type f -name "${file_pattern}" -perm +111 -exec strip -S {} \;
  else
    find ${target_dir} -type f -name "${file_pattern}" -executable -exec strip --strip-debug {} \;
  fi
}
