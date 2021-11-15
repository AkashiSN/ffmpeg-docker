# export image
FROM scratch AS export

ARG FFMPEG_VERSION=4.4

FROM akashisn/ffmpeg:${FFMPEG_VERSION} as ffmpeg-image

COPY --from=ffmpeg-image /usr/local/bin /
COPY --from=ffmpeg-image /usr/local/configure_options /
COPY --from=ffmpeg-image /usr/local/run.sh /


# export qsv image
FROM scratch AS export-qsv

ARG FFMPEG_VERSION=4.4

FROM akashisn/ffmpeg:${FFMPEG_VERSION}-qsv as ffmpeg-image-qsv

COPY --from=ffmpeg-image-qsv /usr/local/bin /
COPY --from=ffmpeg-image-qsv /usr/local/lib /
COPY --from=ffmpeg-image-qsv /usr/local/configure_options /
COPY --from=ffmpeg-image-qsv /usr/local/run.sh /
