FROM debian:buster AS ffmpeg-build

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && \
    apt-get install -y make build-essential yasm nasm cmake pkg-config

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""

#
# Video
#

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
# Audio
#

# Build opus
ADD https://github.com/xiph/opus/archive/master.tar.gz /tmp/opus-master.tar.gz
RUN cd /tmp && \
    tar xf opus-master.tar.gz && \
    mkdir /tmp/opus_build && cd /tmp/opus_build && \
    cmake -DBUILD_SHARED_LIBS=OFF ../opus-master && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libopus"

# Build libogg, for vorbis
ADD https://github.com/xiph/ogg/archive/master.tar.gz /tmp/ogg-master.tar.gz
RUN cd /tmp && \
    tar xf ogg-master.tar.gz && \
    mkdir /tmp/ogg_build && cd /tmp/ogg_build && \
    cmake -DBUILD_SHARED_LIBS=OFF ../ogg-master && \
    make -j $(nproc) && \
    make install

# Build vorbis
ADD https://github.com/xiph/vorbis/archive/master.tar.gz /tmp/vorbis-master.tar.gz
RUN cd /tmp && \
    tar xf vorbis-master.tar.gz && \
    mkdir /tmp/vorbis_build && cd /tmp/vorbis_build && \
    cmake -DBUILD_SHARED_LIBS=OFF ../vorbis-master && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvorbis"


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
    cp --archive --parents --no-dereference /usr/local/bin/ff* /build

# final image
FROM debian:buster-slim

COPY --from=ffmpeg-build /build /

WORKDIR /workdir
ENTRYPOINT [ "ffmpeg" ]
CMD [ "--help" ]