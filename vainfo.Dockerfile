FROM ubuntu:22.04 AS vainfo-build

# Install MediaSDK
ENV INTEL_MEDIA_SDK_VERSION=21.3.5
ADD https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}/MediaStack.tar.gz /tmp/
RUN cd /tmp && \
    tar xf MediaStack.tar.gz && \
    cd /tmp/MediaStack/opt/intel/mediasdk && \
    cp --archive --no-dereference bin /usr/local/ && \
    cp --archive --no-dereference lib64/. /usr/local/lib/

# vainfo image
FROM ubuntu:22.04 AS vainfo

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependency
RUN rm -rf /var/lib/apt/lists/* && \
    apt-get update && \
    apt-get install -y libdrm2 libxext6 libxfixes3 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=vainfo-build /usr/local/bin/vainfo /usr/local/bin/
COPY --from=vainfo-build /usr/local/lib/*.so* /usr/local/lib/

ENV LIBVA_DRIVERS_PATH=/usr/local/lib \
    LIBVA_DRIVER_NAME=iHD

RUN ldconfig

WORKDIR /workdir
ENTRYPOINT [ "vainfo" ]