# ffmpeg-docker

[![ffmpeg](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg.yml/badge.svg)](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg.yml)

[![](https://dockeri.co/image/akashisn/ffmpeg)](https://hub.docker.com/r/akashisn/ffmpeg)

## Available tags

- [Plain ffmpeg (without HWAccel)](https://github.com/AkashiSN/ffmpeg-docker/blob/main/Dockerfile)
  - `4.4`
  - `4.4.1`
  - `4.3.2`
  - `4.3.3`
- [With Intel QSV(Media SDK)](https://github.com/AkashiSN/ffmpeg-docker/blob/main/qsv.Dockerfile)
  - `4.4-qsv`
  - `4.4.1-qsv`
  - `4.3.2-qsv`
  - `4.3.3-qsv`
- [Windows ffmpeg](https://github.com/AkashiSN/ffmpeg-docker/blob/main/windows.Dockerfile)
  - `4.4.1`
  - `4.3.3`

## Supported architecture

- Plain ffmpeg (without HWAccel)
  - `linux/amd64`
- With Intel QSV
  - `linux/amd64`
- Windows ffmpeg
  - `windows/x64`

## Supported Codecs

- `VP8/VP9/webm`: VP8 / VP9 Video Codec for the WebM video file format
- `x264`: H.264 Video Codec (MPEG-4 AVC)
- `x265`: H.265 Video Codec (HEVC)
- `AV1`: AV1 Video Codec
- `vorbis`: Lossy audio compression format
- `opus`: Lossy audio coding format
- `freetype`: Library to render fonts
- `fribidi`:  Implementation of the Unicode Bidirectional Algorithm
- `fontconfig`: Library for configuring and customizing font access
- `libass`: Portable subtitle renderer for the ASS/SSA
- `aribb24`: A library for ARIB STD-B24, decoding JIS 8 bit characters and parsing MPEG-TS stream

### HWAccel

- `mfx`: Intel QSV (Intel Quick Sync Video)
- `vaapi`: Intel Media Driver for VAAPI
- `cuda`: NVIDIA's GPU accelerated video codecs

## Intel QSV (Intel Quick Sync Video)

https://trac.ffmpeg.org/wiki/Hardware/QuickSync

You can use the following command to find out which codecs are supported by your CPU.

```bash
$ docker run --rm -it --device=/dev/dri akashisn/vainfo
error: cant connect to X server!
libva info: VA-API version 1.13.0
libva info: User environment variable requested driver 'iHD'
libva info: Trying to open /usr/local/lib/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_13
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.13 (libva 2.12.0)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 21.3.4 (46458db8)
vainfo: Supported profile and entrypoints
      VAProfileNone                   : VAEntrypointVideoProc
      VAProfileNone                   : VAEntrypointStats
      VAProfileMPEG2Simple            : VAEntrypointVLD
      VAProfileMPEG2Simple            : VAEntrypointEncSlice
      VAProfileMPEG2Main              : VAEntrypointVLD
      VAProfileMPEG2Main              : VAEntrypointEncSlice
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSlice
      VAProfileH264Main               : VAEntrypointFEI
      VAProfileH264Main               : VAEntrypointEncSliceLP
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSlice
      VAProfileH264High               : VAEntrypointFEI
      VAProfileH264High               : VAEntrypointEncSliceLP
      VAProfileVC1Simple              : VAEntrypointVLD
      VAProfileVC1Main                : VAEntrypointVLD
      VAProfileVC1Advanced            : VAEntrypointVLD
      VAProfileJPEGBaseline           : VAEntrypointVLD
      VAProfileJPEGBaseline           : VAEntrypointEncPicture
      VAProfileH264ConstrainedBaseline: VAEntrypointVLD
      VAProfileH264ConstrainedBaseline: VAEntrypointEncSlice
      VAProfileH264ConstrainedBaseline: VAEntrypointFEI
      VAProfileH264ConstrainedBaseline: VAEntrypointEncSliceLP
      VAProfileVP8Version0_3          : VAEntrypointVLD
      VAProfileVP8Version0_3          : VAEntrypointEncSlice
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointEncSlice
      VAProfileHEVCMain               : VAEntrypointFEI
      VAProfileHEVCMain10             : VAEntrypointVLD
      VAProfileHEVCMain10             : VAEntrypointEncSlice
      VAProfileVP9Profile0            : VAEntrypointVLD
      VAProfileVP9Profile2            : VAEntrypointVLD
```

- `VAEntrypointEncSlice`: Can encode
- `VAEntrypointVLD` : Can decode


## Binary release

You can find the pre-built binary files on the [release page](https://github.com/AkashiSN/ffmpeg-docker/releases).

There are files in the assets with the following naming conventions:

```
ffmpeg-${version}-${"qsv" or ""}-${"linux" or "windows"}-${arch}.tar.gz
```

In `qsv` archive file:

```bash
$ ls
bin  configure_options  lib  run.sh
$ ls bin/
ffmpeg  ffprobe
$ ls lib/
iHD_drv_video.so     libigfxcmrt.so.7       libmfx.so        libmfxhw64.so.1.35     libva.so.2
libigdgmm.so         libigfxcmrt.so.7.2.0   libmfx.so.1      libva-drm.so           libva.so.2.1300.0
libigdgmm.so.11      libmfx-tracer.so       libmfx.so.1.35   libva-drm.so.2
libigdgmm.so.11.3.0  libmfx-tracer.so.1     libmfxhw64.so    libva-drm.so.2.1300.0
libigfxcmrt.so       libmfx-tracer.so.1.35  libmfxhw64.so.1  libva.so
$ cat run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib
export LIBVA_DRIVER_NAME=iHD
exec $@
```

If you use `run.sh`, you can run it after setting the `LD_LIBRARY_PATH` and other settings.

And, if you want to encode with QSV, you need to run it with root privileges.

sample:

```bash
$ sudo ./run.sh ffmpeg \
          -init_hw_device qsv=qsv:hw -hwaccel qsv \
          -i https://files.coconut.co.s3.amazonaws.com/test.mp4 \
          -c:v h264_qsv \
          -f mp4 \
          test-h264_qsv.mp4
```

## Docker image release

When running in Docker, you need to mount the DRI device.

sample:
```bash
$ docker run --rm -it --device=/dev/dri -v `pwd`:/workdir \
  akashisn/ffmpeg:4.4-qsv -y \
    -init_hw_device qsv=qsv:hw -hwaccel qsv -filter_hw_device qsv -hwaccel_output_format qsv \
    -fflags +discardcorrupt \
    -analyzeduration 10M -probesize 32M \
    -i AB1.m2ts \
    -t 30 \
    -c:v h264_qsv \
    -global_quality 20 \
    -vf hwupload=extra_hw_frames=64,vpp_qsv=deinterlace=2,scale_qsv=1920:-1,fps=30000/1001 \
    -c:a aac -ar 48000 -ab 256k \
    -f mp4 \
    AB1_h264_qsv.mp4
```

# Nonfree codecs

If you want to use a non-free codec(e.g. `fdk-aac`, `libnpp` ), you can generate a binary in the current directory by executing the following command.

**Generated binaries cannot be redistributed due to licensing issues. Please use them for your own use only.**

```bash
# for windows build
# $ export CUDA_SDK_VERSION=11.4.2
# $ export NVIDIA_DRIVER_VERSION=471.41
# $ curl -L -o ./cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_win10.exe https://developer.download.nvidia.com/compute/cuda/${CUDA_SDK_VERSION}/local_installers/cuda_${CUDA_SDK_VERSION}_${NVIDIA_DRIVER_VERSION}_win10.exe
$ docker buildx build --build-arg HOST_TARGET=x86_64-w64-mingw32 --build-arg TARGET_OS=windows --output type=local,dest=build -t ffmpeg-nonfree:windows -f ./nonfree.Dockerfile .

# for linux build
$ docker buildx build --output type=local,dest=build -t ffmpeg-nonfree:windows -f ./nonfree.Dockerfile .
```

