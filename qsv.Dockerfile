# syntax = docker/dockerfile:1.3-labs

FROM ubuntu:20.04 AS ffmpeg-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN <<EOT
rm -rf /var/lib/apt/lists/*
sed -i -r 's!(deb|deb-src) \S+!\1 http://jp.archive.ubuntu.com/ubuntu/!' /etc/apt/sources.list
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

# Environment
ENV TARGET_OS="Linux" \
    PREFIX="/usr/local" \
    WORKDIR="/workdir"

WORKDIR ${WORKDIR}

# Copy build script
ADD ./scripts/*.sh ./


#
# HWAccel
#

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.3.5
RUN apt-get install -y libdrm2 libxext6 libxfixes3
RUN <<EOT
source ./base.sh
download_and_unpack_file "https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz"
cd opt/intel/mediasdk
cp --archive --no-dereference include ${PREFIX}/
cp --archive --no-dereference lib64/. ${PREFIX}/lib/
ldconfig
echo -n "`cat ${PREFIX}/ffmpeg_configure_options` --enable-libmfx --enable-vaapi" > ${PREFIX}/ffmpeg_configure_options
EOT


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
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib
export LIBVA_DRIVER_NAME=iHD
exec $@
EOT

# Copy artifacts
RUN <<EOT
mkdir /build
chmod +x ${PREFIX}/run.sh
cp --archive --parents --no-dereference ${PREFIX}/run.sh /build
cp --archive --parents --no-dereference ${PREFIX}/bin/ff* /build
cp --archive --parents --no-dereference ${PREFIX}/configure_options /build
cp --archive --parents --no-dereference ${PREFIX}/lib/*.so* /build
rm /build/${PREFIX}/lib/libva-glx.so*
rm /build/${PREFIX}/lib/libva-x11.so*
EOT


# Final ffmpeg image
FROM ubuntu:20.04 AS ffmpeg

SHELL ["/bin/sh", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependency
RUN <<EOT
rm -rf /var/lib/apt/lists/*
sed -i -r 's!(deb|deb-src) \S+!\1 http://jp.archive.ubuntu.com/ubuntu/!' /etc/apt/sources.list
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
