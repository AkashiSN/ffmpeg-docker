FROM ubuntu:20.04 AS ffmpeg-build

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      cmake \
      curl \
      make \
      nasm \
      pkg-config \
      yasm

# ffmpeg-build-base-image
COPY --from=ghcr.io/akashisn/ffmpeg-build-base / /

#
# HWAccel
#

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.3.5
RUN curl -sL -o /tmp/MediaStack.tar.gz https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz
RUN apt-get install -y libdrm2 libxext6 libxfixes3
RUN cd /tmp && \
    tar xf MediaStack.tar.gz && \
    cd /tmp/MediaStack/opt/intel/mediasdk && \
    cp --archive --no-dereference include /usr/local/ && \
    cp --archive --no-dereference lib64/. /usr/local/lib/ && \
    ldconfig
RUN echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libmfx --enable-vaapi" > /usr/local/ffmpeg_configure_options

#
# Build ffmpeg
#
ARG FFMPEG_VERSION=4.4
RUN curl -sL -o /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz  https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz && \
    cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
    ./configure `cat /usr/local/ffmpeg_configure_options` \
                --disable-autodetect \
                --disable-debug \
                --disable-doc \
                --disable-ffplay \
                --enable-gpl \
                --enable-small \
                --enable-version3 \
                --extra-libs="`cat /usr/local/ffmpeg_extra_libs`" \
                --pkg-config-flags="--static" > /usr/local/configure_options  && \
    make -j $(nproc) && \
    make install

# Copy artifacts
RUN mkdir /build && \
    cp --archive --parents --no-dereference /usr/local/bin/ff* /build && \
    cp --archive --parents --no-dereference /usr/local/configure_options /build && \
    cp --archive --parents --no-dereference /usr/local/lib/*.so* /build && \
    rm /build/usr/local/lib/libva-glx.so* && \
    rm /build/usr/local/lib/libva-x11.so* && \
    cd /build/usr/local/ && \
    echo '#!/bin/sh' > run.sh && \
    echo '' >> run.sh && \
    echo 'export PATH=$(pwd)/bin:$PATH' >> run.sh && \
    echo 'export LD_LIBRARY_PATH=$(pwd)/lib:$LD_LIBRARY_PATH' >> run.sh && \
    echo 'LIBVA_DRIVERS_PATH=$(pwd)/lib' >> run.sh && \
    echo 'LIBVA_DRIVER_NAME=iHD' >> run.sh && \
    echo '' >> run.sh && \
    echo 'exec $@' >> run.sh && \
    chmod +x run.sh

# final ffmpeg image
FROM ubuntu:20.04 AS ffmpeg

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependency
RUN apt-get update && \
    apt-get install -y libdrm2 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=ffmpeg-build /build /

ENV LIBVA_DRIVERS_PATH=/usr/local/lib \
    LIBVA_DRIVER_NAME=iHD

RUN ldconfig

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]


# export image
FROM scratch AS export

COPY --from=ffmpeg-build /build/usr/local/ /