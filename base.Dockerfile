FROM debian:buster AS ffmpeg-build

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && \
    apt-get install -y \
      autoconf \
      automake \
      autopoint \
      build-essential \
      cmake \
      curl \
      gettext \
      git \
      gperf \
      libtool \
      make \
      nasm \
      pkg-config \
      python3 \
      yasm

ENV FFMPEG_CONFIGURE_OPTIONS="" \
    FFMPEG_EXTRA_LIBS=""

#
# Video
#

# Build libvpx
ADD https://github.com/webmproject/libvpx/archive/master.tar.gz /tmp/libvpx-master.tar.gz
RUN cd /tmp && \
    tar xf libvpx-master.tar.gz && \
    mkdir /tmp/libvpx_build && cd /tmp/libvpx_build && \
    ../libvpx-master/configure --disable-unit-tests --as=yasm && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libvpx"

# Build x264
ADD https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2 /tmp/
RUN cd /tmp && \
    tar xf x264-master.tar.bz2 && \
    mkdir /tmp/x264_build && cd /tmp/x264_build && \
    ../x264-master/configure && \
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

# Build libaom
RUN git clone https://aomedia.googlesource.com/aom -b master --depth 1 /tmp/aom
RUN mkdir /tmp/aom_build && cd /tmp/aom_build && \
    cmake -DENABLE_SHARED=off -DBUILD_SHARED_LIBS=OFF -DENABLE_NASM=on ../aom && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaom"


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
# Caption
#

# freetype
RUN git clone https://gitlab.freedesktop.org/freetype/freetype.git -b master --depth 1 /tmp/freetype
RUN cd /tmp/freetype && \
    ./autogen.sh && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfreetype"

# fribidi
RUN git clone https://github.com/fribidi/fribidi.git -b master --depth 1 /tmp/fribidi
RUN cd /tmp/fribidi && \
    ./autogen.sh && \
    ./configure --enable-static --disable-shared && \
    make && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfribidi"

# libexpat
ADD https://github.com/libexpat/libexpat/archive/master.tar.gz /tmp/libexpat-master.tar.gz
RUN cd /tmp && \
    tar xf /tmp/libexpat-master.tar.gz && \
    cd /tmp/libexpat-master/expat && \
    ./buildconf.sh && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install

# fontconfig
RUN git clone https://gitlab.freedesktop.org/fontconfig/fontconfig.git -b main --depth 1 /tmp/fontconfig
RUN cd /tmp/fontconfig && \
    ./autogen.sh && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libfontconfig"

# libharfbuzz
ADD https://github.com/harfbuzz/harfbuzz/archive/main.tar.gz /tmp/harfbuzz-main.tar.gz
RUN cd /tmp && \
    tar xf harfbuzz-main.tar.gz && \
    cd /tmp/harfbuzz-main && \
    ./autogen.sh && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install

# libass
ADD https://github.com/libass/libass/archive/master.tar.gz /tmp/libass-master.tar.gz
RUN cd /tmp && \
    tar xf libass-master.tar.gz && \
    cd /tmp/libass-master && \
    ./autogen.sh && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libass"

# zlib
ENV ZLIB_VERSION=1.2.11
RUN curl -sL -o /tmp/zlib-${ZLIB_VERSION}.tar.xz https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf zlib-${ZLIB_VERSION}.tar.xz && \
    cd /tmp/zlib-${ZLIB_VERSION} && \
    ./configure --static && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-zlib"

# libpng
ENV LIBPNG_VERSION=1.6.37
RUN curl -sL -o /tmp/libpng-${LIBPNG_VERSION}.tar.xz https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz
RUN cd /tmp && \
    tar xf libpng-${LIBPNG_VERSION}.tar.xz && \
    cd /tmp/libpng-${LIBPNG_VERSION} && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install

# libaribb24
ADD https://salsa.debian.org/multimedia-team/aribb24/-/archive/master/aribb24-master.tar.bz2 /tmp/
RUN cd /tmp && \
    tar xf aribb24-master.tar.bz2 && \
    cd /tmp/aribb24-master && \
    ./bootstrap && \
    ./configure --enable-static --disable-shared && \
    make -j $(nproc) && \
    make install
ENV FFMPEG_CONFIGURE_OPTIONS="${FFMPEG_CONFIGURE_OPTIONS} --enable-libaribb24"


#
# Copy artifacts
#
RUN mkdir /build && \
    cp --archive --parents --no-dereference /usr/local/lib /build && \
    cp --archive --parents --no-dereference /usr/local/include /build && \
    echo $FFMPEG_CONFIGURE_OPTIONS > /build/usr/local/ffmpeg_configure_options && \
    echo $FFMPEG_EXTRA_LIBS > /build/usr/local/ffmpeg_extra_libs


# final image
FROM scratch

COPY --from=ffmpeg-build /build /