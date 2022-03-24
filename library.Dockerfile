# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-library-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
rm -rf /var/lib/apt/lists/*
apt-get update
apt-get install -y \
    autopoint \
    build-essential \
    clang \
    curl \
    gettext \
    git \
    gperf \
    libtool \
    lzip \
    make \
    mingw-w64 \
    mingw-w64-tools \
    nasm \
    pkg-config \
    subversion \
    yasm
EOT

# Environment
ARG TARGET_OS="Linux"
ENV TARGET_OS=${TARGET_OS} \
    PREFIX="/usr/local" \
    WORKDIR="/workdir"

WORKDIR ${WORKDIR}


#
# Build Library
#

# Copy build script
ADD *.sh ./

# Run build
RUN bash ./build-library.sh


#
# Copy artifacts
#
RUN <<EOT
mkdir /build
rm -r ${PREFIX}/lib/python3.8
cp --archive --parents --no-dereference ${PREFIX}/lib /build
cp --archive --parents --no-dereference ${PREFIX}/include /build
cp --archive --parents --no-dereference ${PREFIX}/ffmpeg_extra_libs /build
cp --archive --parents --no-dereference ${PREFIX}/ffmpeg_configure_options /build
EOT


# final image
FROM scratch

COPY --from=ffmpeg-library-build /build /