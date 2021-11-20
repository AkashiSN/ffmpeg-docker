# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/sh", "-e", "-c"]
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

# ffmpeg-library-build image
COPY --from=ghcr.io/akashisn/ffmpeg-library-build:linux / /


#
# Build ffmpeg
#
ARG FFMPEG_VERSION=4.4.1
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN <<EOT
tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz -C /tmp
cd /tmp/ffmpeg-${FFMPEG_VERSION}
./configure `cat /usr/local/ffmpeg_configure_options` \
            --disable-autodetect \
            --disable-debug \
            --disable-doc \
            --disable-ffplay \
            --enable-gpl \
            --enable-version3 \
            --extra-libs="`cat /usr/local/ffmpeg_extra_libs`" \
            --pkg-config-flags="--static" > /usr/local/configure_options
make -j $(nproc)
make install
EOT

# Copy run.sh
COPY <<'EOT' /usr/local/run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
exec $@
EOT

# Copy artifacts
RUN <<EOT
mkdir /build
chmod +x /usr/local/run.sh
cp --archive --parents --no-dereference /usr/local/run.sh /build
cp --archive --parents --no-dereference /usr/local/bin/ff* /build
cp --archive --parents --no-dereference /usr/local/configure_options /build
EOT


# Final ffmpeg image
FROM ubuntu:20.04 AS ffmpeg

COPY --from=ffmpeg-build /build /

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]
