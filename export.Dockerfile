# syntax=docker/dockerfile:1.3

ARG FFMPEG_VERSION=4.4

FROM akashisn/ffmpeg:${FFMPEG_VERSION} as ffmpeg-image
FROM akashisn/ffmpeg:${FFMPEG_VERSION}-qsv as ffmpeg-image-qsv


# export image
FROM scratch AS export

COPY --from=ffmpeg-image /usr/local/bin /bin
COPY --from=ffmpeg-image /usr/local/configure_options /
COPY --from=ffmpeg-image /usr/local/run.sh /


# export qsv image
FROM scratch AS export-qsv

COPY --from=ffmpeg-image-qsv /usr/local/bin /bin
COPY --from=ffmpeg-image-qsv /usr/local/lib /lib
COPY --from=ffmpeg-image-qsv /usr/local/configure_options /
COPY --from=ffmpeg-image-qsv /usr/local/run.sh /
