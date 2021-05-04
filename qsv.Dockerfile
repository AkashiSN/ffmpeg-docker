# ffmpeg-build-base-image
FROM akashisn/ffmpeg-build-base AS ffmpeg-build-base-image


FROM debian:buster AS ffmpeg-build

# Install build tools
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      cmake \
      make \
      nasm \
      pkg-config \
      yasm

COPY --from=ffmpeg-build-base-image /build /

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
RUN echo -n "`cat /usr/local/ffmpeg_configure_options` --enable-libmfx" > /usr/local/ffmpeg_configure_options

#
# Build ffmpeg
#
ENV FFMPEG_VERSION=4.4
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN cd /tmp && \
    tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz && \
    cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
    ./configure `cat /usr/local/ffmpeg_configure_options` \
                --disable-debug \
                --enable-small \
                --enable-gpl \
                --enable-version3 \
                --extra-libs="`cat /usr/local/ffmpeg_extra_libs`" \
                --pkg-config-flags="--static" && \
    make -j $(nproc) && \
    make install

# Copy artifacts
RUN mkdir /build && \
    cp /tmp/MediaStack/opt/intel/mediasdk/bin/vainfo /usr/local/bin/ && \
    cp --archive --parents --no-dereference /usr/local/bin/ff* /build && \
    cp --archive --parents --no-dereference /usr/local/bin/vainfo /build && \
    cp --archive --parents --no-dereference /usr/local/lib/*.so* /build


# final image
FROM debian:buster-slim

# Install runtime dependency
RUN apt-get update && \
    apt-get install -y libdrm2 libx11-6 libxext6 libxfixes3 && \
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