FROM ubuntu:20.04 AS ffmpeg-build

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      cmake \
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
ADD https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz /tmp/
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
ADD https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz /tmp/
RUN cd /tmp && \
    tar xf /tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz && \
    cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
    ./configure `cat /usr/local/ffmpeg_configure_options` \
                --disable-autodetect \
                --disable-debug \
                --disable-doc \
                --disable-ffplay \
                --enable-gpl \
                --enable-nonfree \
                --enable-small \
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
    cp --archive --parents --no-dereference /usr/local/lib/*.so* /build && \
    rm /build/usr/local/lib/libva-glx.so* && \
    # libdrm2
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libdrm.so.2* /build/usr/local/lib/ && \
    # libxext6
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libXext.so.6* /build/usr/local/lib/ && \
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libX11.so.6* /build/usr/local/lib/ && \
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libxcb.so.1* /build/usr/local/lib/ && \
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libXau.so.6* /build/usr/local/lib/ && \
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libXdmcp.so.6* /build/usr/local/lib/ && \
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libbsd.so.0* /build/usr/local/lib/ && \
    # libxfixes3
    cp --archive --no-dereference /usr/lib/x86_64-linux-gnu/libXfixes.so.3* /build/usr/local/lib/


# final image
FROM ubuntu:20.04 AS releases

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