#!/bin/bash
set -eu

# Environment
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/usr/sbin:/bin:/usr/bin
export TARGET_OS="Darwin"
export PREFIX="$HOME/.local"
export WORKDIR="$HOME/workdir"
export FFMPEG_VERSION="5.0.1"

GCC_VERSION="11"

# Install build tools
brew update

FORMULAS+=(
  autoconf
  automake
  gcc@${GCC_VERSION}
  gettext
  git
  gperf
  libtool
  lzip
  make
  nasm
  pkg-config
  subversion
  yasm
)

for formula in ${FORMULAS[@]}; do
  if brew ls --versions ${formula} ; then
    brew upgrade ${formula}
  else
    brew install ${formula}
  fi
done

# Link gcc
rm -f /usr/local/bin/gcc
rm -f /usr/local/bin/g++
ln -s /usr/local/bin/gcc-${GCC_VERSION} /usr/local/bin/gcc
ln -s /usr/local/bin/g++-${GCC_VERSION} /usr/local/bin/g++

# Link make
rm -f /usr/local/bin/make
ln -s /usr/local/bin/gmake /usr/local/bin/make


#
# Build Library
#

bash ./build-library.sh


#
# Build FFmpeg
#

bash ./build-ffmpeg.sh
