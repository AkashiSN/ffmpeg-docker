FROM debian:buster AS ffmpeg-build

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && \
    apt-get install -y make build-essential yasm nasm cmake pkg-config

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""

# Build libvpx
ADD https://github.com/webmproject/libvpx/archive/master.tar.gz /tmp/libvpx-master.tar.gz
RUN cd /tmp && \
    tar xf libvpx-master.tar.gz && \
    cd /tmp/libvpx-master && \
    ./configure --disable-unit-tests --as=yasm && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvpx"

# Build x264
ADD https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2 /tmp/
RUN cd /tmp && \
    tar xf x264-master.tar.bz2 && \
    cd /tmp/x264-master && \
    ./configure && \
    make -j $(nproc) && \
    make install && \
    make install-cli && \
    make install-lib-static
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx264"

# Build x265
ADD https://github.com/videolan/x265/archive/master.tar.gz /tmp/x265-master.tar.gz
RUN cd /tmp && \
    tar xf x265-master.tar.gz && \
    mkdir /tmp/x265_build && cd /tmp/x265_build && \
    cmake -DENABLE_SHARED=off -DBUILD_SHARED_LIBS=OFF ../x265-master/source && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libx265" \
    FFMPEG_EXTRA_LIBS="${FFMPEG_EXTRA_LIBS} -lpthread"

#
# HWAccel
#

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.1.3
ADD https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz /tmp/
RUN apt-get install -y libdrm2
RUN cd /tmp && \
    tar xf MediaStack.tar.gz && \
    cd /tmp/MediaStack/opt/intel/mediasdk && \
    cp --archive --no-dereference include /usr/local/ && \
    cp --archive --no-dereference lib64/. /usr/local/lib/ && \
    ldconfig
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libmfx"

#
# Build ffmpeg
#
ENV FFMPEG_VERSION=4.4
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN cd /tmp && \
    tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz && \
    cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
    ./configure ${FFMPEG_CONFIGURE_OPTIONS} \
                --disable-debug \
                --enable-small \
                --enable-gpl \
                --enable-version3 \
                --extra-libs="${FFMPEG_EXTRA_LIBS}" \
                --pkg-config="pkg-config --static" && \
    make -j $(nproc) && \
    make install

# Copy artifacts
RUN mkdir /build && \
    cp --archive --parents --no-dereference /usr/local/bin/ff* /build && \
    cp --archive --parents --no-dereference /usr/local/lib/*.so* /build


# final image
FROM debian:buster-slim

# Install runtime dependency
RUN apt-get update && \
    apt-get install -y libdrm2 && \
    apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=ffmpeg-build /build /

ENV LIBVA_DRIVERS_PATH=/usr/local/lib \
    LIBVA_DRIVER_NAME=iHD

RUN ldconfig

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]