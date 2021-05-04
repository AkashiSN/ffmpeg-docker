# ffmpeg-docker

![](https://dockeri.co/image/akashisn/ffmpeg)

## Available tags

- [latest](https://github.com/AkashiSN/ffmpeg-docker/blob/main/Dockerfile): Plain ffmpeg (without HWAccel)
- [qsv](https://github.com/AkashiSN/ffmpeg-docker/blob/main/qsv.Dockerfile): With Intel QSV

## Intel QSV (Intel Quick Sync Video)

[![ffmpeg-qsv](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg-qsv.yml/badge.svg)](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg-qsv.yml)

https://trac.ffmpeg.org/wiki/Hardware/QuickSync

You can use the following command to find out which codecs are supported by your CPU.

```bash
$ docker run --rm -it --device=/dev/dri --entrypoint=vainfo akashisn/ffmpeg:qsv
error: cant connect to X server!
libva info: VA-API version 1.11.0
libva info: User environment variable requested driver 'iHD'
libva info: Trying to open /usr/local/lib/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_11
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.11 (libva 2.11.1)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 21.1.3 (bec8e138)
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

### H.264 (Sandy Bridge ~)

#### Intel(R) Media SDK

https://github.com/Intel-Media-SDK/MediaSDK

```bash
$ docker run --rm -it akashisn/ffmpeg:qsv -h encoder=h264_qsv
```

```bash
$ docker run --rm -it --device=/dev/dri -v `pwd`:/workdir \
  akashisn/ffmpeg:qsv -y \
    -init_hw_device qsv=qsv:hw -hwaccel qsv -filter_hw_device qsv -hwaccel_output_format qsv \
    -fflags +discardcorrupt \
    -analyzeduration 30M -probesize 100MB \
    -i AB1.m2ts \
    -vf hwupload=extra_hw_frames=64,vpp_qsv=deinterlace=2,vpp_qsv=w=1920:h=1080,fps=30000/1001 \
    -c:v h264_qsv \
    -q:v 20 \
    -c:a copy \
    -bsf:a aac_adtstoasc \
    AB1_h264_qsv.mp4
```

#### Intel(R) Media Driver for VAAPI

https://github.com/intel/media-driver

```bash
$ docker run --rm -it akashisn/ffmpeg:qsv -h encoder=h264_vaapi
```

```bash
$ docker run --rm -it --device=/dev/dri -v `pwd`:/workdir \
  akashisn/ffmpeg:qsv -y \
    -hwaccel vaapi -hwaccel_output_format vaapi \
    -fflags +discardcorrupt \
    -analyzeduration 30M -probesize 100MB \
    -i AB1.m2ts \
    -vf hwupload=extra_hw_frames=64,deinterlace_vaapi,scale_vaapi=1920:1080,sharpness_vaapi,fps=30000/1001 \
    -c:v h264_vaapi \
    -qp 20 \
    -c:a copy \
    -bsf:a aac_adtstoasc \
    AB1_h264_vaapi.mp4
```

### H.265 (Skylake ~), H.265 Main10 (Kaby Lake ~)


#### Intel(R) Media SDK

https://github.com/Intel-Media-SDK/MediaSDK


```bash
$ docker run --rm -it akashisn/ffmpeg:qsv -h encoder=hevc_qsv
```

```bash
$ docker run --rm -it --device=/dev/dri -v `pwd`:/workdir \
  akashisn/ffmpeg:qsv -y \
    -init_hw_device qsv=qsv:hw -hwaccel qsv -filter_hw_device qsv -hwaccel_output_format qsv \
    -fflags +discardcorrupt \
    -analyzeduration 30M -probesize 100MB \
    -i AB1.m2ts \
    -vf hwupload=extra_hw_frames=64,vpp_qsv=deinterlace=2,vpp_qsv=w=1920:h=1080,fps=30000/1001 \
    -c:v hevc_qsv \
    -q:v 20 \
    -c:a copy \
    -bsf:a aac_adtstoasc \
    AB1_h265_qsv.mp4
```

#### Intel(R) Media Driver for VAAPI

https://github.com/intel/media-driver

```bash
$ docker run --rm -it akashisn/ffmpeg:qsv -h encoder=hevc_vaapi
```

```bash
$ docker run --rm -it --device=/dev/dri -v `pwd`:/workdir \
  akashisn/ffmpeg:qsv -y \
    -hwaccel vaapi -hwaccel_output_format vaapi \
    -fflags +discardcorrupt \
    -analyzeduration 30M -probesize 100MB \
    -i AB1.m2ts \
    -vf hwupload=extra_hw_frames=64,deinterlace_vaapi,scale_vaapi=1920:1080,sharpness_vaapi,fps=30000/1001 \
    -c:v hevc_vaapi \
    -qp 20 \
    -c:a copy \
    -bsf:a aac_adtstoasc \
    AB1_h265_vaapi.mp4
```

### VP8 (Braswell ~)

#### Intel(R) Media Driver for VAAPI

https://github.com/intel/media-driver

```bash
$ docker run --rm -it akashisn/ffmpeg:qsv -h encoder=vp8_vaapi
```

```bash
$ docker run --rm -it --device=/dev/dri -v `pwd`:/workdir \
  akashisn/ffmpeg:qsv -y \
    -hwaccel vaapi -hwaccel_output_format vaapi \
    -fflags +discardcorrupt \
    -analyzeduration 30M -probesize 100MB \
    -i AB1.m2ts \
    -vf hwupload=extra_hw_frames=64,deinterlace_vaapi,scale_vaapi=1920:1080,sharpness_vaapi,fps=30000/1001 \
    -c:v vp8_vaapi \
    -crf 5 \
    -b:v 2000k -minrate 1500k -maxrate 2500k \
    -c:a libopus \
    -b:a 192k \
    AB1_vp8_vaapi.webm
```
