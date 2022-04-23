# ffmpeg-docker

[![ffmpeg](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg.yml/badge.svg)](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg.yml)

[![](https://dockeri.co/image/akashisn/ffmpeg)](https://hub.docker.com/r/akashisn/ffmpeg)

## Available tags

- [Plain ffmpeg (without HWAccel)](https://github.com/AkashiSN/ffmpeg-docker/blob/main/Dockerfile)
  - `5.0.1`
  - `4.4.2`
- [With Intel QSV(Media SDK)](https://github.com/AkashiSN/ffmpeg-docker/blob/main/qsv.Dockerfile)
  - `5.0.1-qsv`
  - `4.4.2-qsv`
- [Windows ffmpeg](https://github.com/AkashiSN/ffmpeg-docker/blob/main/windows.Dockerfile)
  - `5.0.1`
  - `4.4.2`

## Supported architecture

- ffmpeg (without QSV)
  - `linux/amd64`

    <details>
    <summary>configure options:</summary>

    ```bash
    --enable-zlib --enable-libopenjpeg --enable-libwebp --enable-lzma --enable-gmp --enable-iconv
    --enable-gnutls --enable-libsrt --enable-libvpx --enable-libx264 --enable-libx265 --enable-libaom
    --enable-libopus --enable-libvorbis --enable-libopencore-amrnb --enable-libopencore-amrwb
    --enable-libvo-amrwbenc --enable-libmp3lame --enable-libfreetype --enable-libfribidi --enable-libxml2
    --enable-libfontconfig --enable-libass --enable-libaribb24 --enable-sdl2 --enable-cuda-llvm --enable-ffnvcodec
    --enable-cuvid --enable-nvdec --enable-nvenc --disable-autodetect --disable-debug --disable-doc
    --enable-gpl --enable-version3 --extra-libs='-lpthread -lstdc++' --pkg-config-flags=--static
    ```
    </details>

    <details>
    <summary>Dependent library</summary>

    ```bash
    $ ldd ffmpeg
      linux-vdso.so.1 (0x00007ffde9743000)
      libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007f59a176e000)
      libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f59a174b000)
      libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007f59a1745000)
      libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007f59a1563000)
      libmvec.so.1 => /lib/x86_64-linux-gnu/libmvec.so.1 (0x00007f59a1537000)
      libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007f59a151c000)
      libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f59a1328000)
      /lib64/ld-linux-x86-64.so.2 (0x00007f59a637c000)
    ```
    </details>

- With Intel QSV
  - `linux/amd64`
    <details>
    <summary>configure options:</summary>

      ```bash
      --enable-zlib --enable-libopenjpeg --enable-libwebp --enable-lzma --enable-gmp --enable-iconv
      --enable-gnutls --enable-libsrt --enable-libvpx --enable-libx264 --enable-libx265 --enable-libaom
      --enable-libopus --enable-libvorbis --enable-libopencore-amrnb --enable-libopencore-amrwb
      --enable-libvo-amrwbenc --enable-libmp3lame --enable-libfreetype --enable-libfribidi --enable-libxml2
      --enable-libfontconfig --enable-libass --enable-libaribb24 --enable-sdl2 --enable-cuda-llvm --enable-ffnvcodec
      --enable-cuvid --enable-nvdec --enable-nvenc --enable-libmfx --enable-vaapi --disable-autodetect
      --disable-debug --disable-doc --enable-gpl --enable-version3 --extra-libs='-lpthread -lstdc++'
      --pkg-config-flags=--static
      ```
    </details>

    <details>
    <summary>Dependent library</summary>

    ```bash
    $ ldd ffmpeg
      linux-vdso.so.1 (0x00007ffe71ede000)
      libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007efe5ed87000)
      libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007efe5ed64000)
      libva.so.2 => /home/user/.local/lib/libva.so.2 (0x00007efe5eb3b000)
      libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007efe5eb35000)
      libmfx.so.1 => /home/user/.local/lib/libmfx.so.1 (0x00007efe5e927000)
      libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007efe5e745000)
      libmvec.so.1 => /lib/x86_64-linux-gnu/libmvec.so.1 (0x00007efe5e717000)
      libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007efe5e6fc000)
      libva-drm.so.2 => /home/user/.local/lib/libva-drm.so.2 (0x00007efe5e4f9000)
      libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007efe5e307000)
      /lib64/ld-linux-x86-64.so.2 (0x00007efe639ec000)
      libdrm.so.2 => /lib/x86_64-linux-gnu/libdrm.so.2 (0x00007efe5e2f3000)
    ```
    </details>


- Windows ffmpeg
  - `windows/x64`
    <details>
    <summary>configure options:</summary>

    ```bash
    --enable-zlib --enable-libopenjpeg --enable-libwebp --enable-lzma --enable-gmp --enable-iconv
    --enable-gnutls --enable-libsrt --enable-libvpx --enable-libx264 --enable-libx265 --enable-libaom
    --enable-libopus --enable-libvorbis --enable-libopencore-amrnb --enable-libopencore-amrwb
    --enable-libvo-amrwbenc --enable-libmp3lame --enable-libfreetype --enable-libfribidi --enable-libxml2
    --enable-libfontconfig --enable-libass --enable-libaribb24 --enable-sdl2 --enable-cuda-llvm --enable-ffnvcodec
    --enable-cuvid --enable-nvdec --enable-nvenc --enable-libmfx --enable-d3d11va --enable-dxva2
    --arch=x86_64 --cross-prefix=x86_64-w64-mingw32- --disable-autodetect --disable-debug
    --disable-doc --disable-w32threads --enable-cross-compile --enable-gpl --enable-version3
    --extra-libs='-lpthread -lstdc++' --target-os=mingw64 --pkg-config=pkg-config
    --pkg-config-flags=--static
    ```
    </details>

    <details>
    <summary>Dependent library</summary>

    ```bat
    > dumpbin /Dependents C:\tools\media\ffmpeg\ffmpeg.exe
    Microsoft (R) COFF/PE Dumper Version 14.30.30705.0
    Copyright (C) Microsoft Corporation.  All rights reserved.


    Dump of file C:\tools\media\ffmpeg\ffmpeg.exe

    File Type: EXECUTABLE IMAGE

      Image has the following dependencies:

        ADVAPI32.dll
        bcrypt.dll
        CRYPT32.dll
        GDI32.dll
        KERNEL32.dll
        msvcrt.dll
        ole32.dll
        OLEAUT32.dll
        PSAPI.DLL
        SHELL32.dll
        SHLWAPI.dll
        USER32.dll
        AVICAP32.dll
        WS2_32.dll

      Summary

            1000 .CRT
          85C000 .bss
          17000 .data
            B000 .edata
            5000 .idata
          C9000 .pdata
          985000 .rdata
          2B000 .reloc
            1000 .rodata
        3634000 .text
            1000 .tls
          FE000 .xdata
    ```
    </details>


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

```powershell
# for windows build
> $Env:CUDA_SDK_VERSION = "11.6.0"
> $Env:NVIDIA_DRIVER_VERSION = "511.23"
> curl -L -o cuda_${Env:CUDA_SDK_VERSION}_${Env:NVIDIA_DRIVER_VERSION}_windows.exe https://developer.download.nvidia.com/compute/cuda/${Env:CUDA_SDK_VERSION}/local_installers/cuda_${Env:CUDA_SDK_VERSION}_${Env:NVIDIA_DRIVER_VERSION}_windows.exe
> docker buildx build --build-arg HOST_TARGET=x86_64-w64-mingw32 --build-arg TARGET_OS=windows --build-arg CUDA_SDK_VERSION=${Env:CUDA_SDK_VERSION} --build-arg NVIDIA_DRIVER_VERSION=${Env:NVIDIA_DRIVER_VERSION} --output type=local,dest=build -t ffmpeg-nonfree:windows -f ./nonfree.Dockerfile .
```

```bash
# for linux build
$ touch cuda_11.6.0_511.23_windows.exe # dummy file
$ docker buildx build --output type=local,dest=build -t ffmpeg-nonfree:linux -f ./nonfree.Dockerfile .
```
