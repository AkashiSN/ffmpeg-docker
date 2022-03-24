# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
apt-get update
apt-get install -y \
    build-essential \
    clang \
    curl \
    make \
    nasm \
    pkg-config \
    yasm
EOT

# Environment
ENV TARGET_OS="Linux" \
    PREFIX="/usr/local" \
    WORKDIR="/workdir"

WORKDIR ${WORKDIR}

# Copy build script
ADD *.sh ./

# ffmpeg-library-build image
COPY --from=ghcr.io/akashisn/ffmpeg-library-build:linux / /


#
# Build ffmpeg
#
ARG FFMPEG_VERSION=5.0
ENV FFMPEG_VERSION="${FFMPEG_VERSION}"

# Run build
RUN bash ./build-ffmpeg.sh

# Copy run.sh
COPY <<'EOT' ${PREFIX}/run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
exec $@
EOT

# Copy artifacts
RUN <<EOT
mkdir /build
chmod +x ${PREFIX}/run.sh
cp --archive --parents --no-dereference ${PREFIX}/run.sh /build
cp --archive --parents --no-dereference ${PREFIX}/bin/ff* /build
cp --archive --parents --no-dereference ${PREFIX}/configure_options /build
EOT


# Final ffmpeg image
FROM ubuntu:20.04 AS ffmpeg

COPY --from=ffmpeg-build /build /

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]
