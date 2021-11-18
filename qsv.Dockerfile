# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
apt-get update
apt-get install -y \
    build-essential \
    curl \
    make \
    nasm \
    pkg-config \
    yasm
EOT

# ffmpeg-build-base-image
COPY --from=ghcr.io/akashisn/ffmpeg-build-base / /

#
# HWAccel
#

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.3.5
ADD https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz /tmp/
RUN apt-get install -y libdrm2 libxext6 libxfixes3
RUN <<EOT
tar xf /tmp/MediaStack.tar.gz -C /tmp
cd /tmp/MediaStack/opt/intel/mediasdk
cp --archive --no-dereference include /usr/local/
cp --archive --no-dereference lib64/. /usr/local/lib/
ldconfig
echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libmfx --enable-vaapi" > /usr/local/ffmpeg_configure_options
EOT

#
# Build ffmpeg
#
ARG FFMPEG_VERSION=4.4
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
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib
export LIBVA_DRIVER_NAME=iHD
exec $@
EOT

# Copy artifacts
RUN <<EOT
mkdir /build
chmod +x /usr/local/run.sh
cp --archive --parents --no-dereference /usr/local/run.sh /build
cp --archive --parents --no-dereference /usr/local/bin/ff* /build
cp --archive --parents --no-dereference /usr/local/configure_options /build
cp --archive --parents --no-dereference /usr/local/lib/*.so* /build
rm /build/usr/local/lib/libva-glx.so*
rm /build/usr/local/lib/libva-x11.so*
EOT


# final ffmpeg image
FROM ubuntu:20.04 AS ffmpeg

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependency
RUN <<EOT
apt-get update
apt-get install -y libdrm2
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
EOT

COPY --from=ffmpeg-build /build /

ENV LIBVA_DRIVERS_PATH=/usr/local/lib \
    LIBVA_DRIVER_NAME=iHD

RUN ldconfig

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]
