# ffmpeg-docker

[![ffmpeg](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg.yml/badge.svg)](https://github.com/AkashiSN/ffmpeg-docker/actions/workflows/ffmpeg.yml)

[![](https://dockeri.co/image/akashisn/ffmpeg)](https://hub.docker.com/r/akashisn/ffmpeg)

## Available tags

- Plain ffmpeg (without HWAccel)
  - `6.0`
  - `5.1.2`
  - `4.4.3`
- With Intel QSV(Media SDK)
  - `6.0-libmfx`
  - `5.1.2-libmfx`
  - `4.4.3-libmfx`
- With Intel QSV(oneVPL)
  - `6.0-libvpl`
  - `5.1.2-libvpl`
  - `4.4.3-libvpl`
- Windows ffmpeg
  - `6.0`
  - `5.1.2`
  - `4.4.3`

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
    --enable-libfontconfig --enable-libass --enable-libaribb24 --enable-sdl2 --enable-cuda-llvm
    --enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc --disable-autodetect --disable-debug
    --disable-doc --enable-gpl --enable-version3 --extra-libs="-lm -lpthread -lstdc++" --pkg-config-flags="--static" --prefix=/usr/local
    ```
    </details>

    <details>
    <summary>Dependent library</summary>

    ```bash
    $ ldd ffmpeg
        linux-vdso.so.1 (0x00007ffc7af61000)
        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007f1ef7cca000)
        libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007f1ef7aa0000)
        libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007f1ef7a80000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f1ef7858000)
        libmvec.so.1 => /lib/x86_64-linux-gnu/libmvec.so.1 (0x00007f1ef775b000)
        /lib64/ld-linux-x86-64.so.2 (0x00007f1efc829000)
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
    --enable-libfontconfig --enable-libass --enable-libaribb24 --enable-sdl2 --enable-cuda-llvm
    --enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc --enable-libmfx --enable-vaapi
    --disable-autodetect --disable-debug --disable-doc --enable-gpl --enable-version3
    --extra-libs="-lm -lpthread -lstdc++" --pkg-config-flags="--static" --prefix=/usr/local
      ```
    </details>

    <details>
    <summary>Dependent library</summary>

    ```bash
    $ ldd ffmpeg
        linux-vdso.so.1 (0x00007ffe367a0000)
        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007efee94db000)
        libva.so.2 => /usr/local/lib/libva.so.2 (0x00007efee9200000)
        libmfx.so.1 => /usr/local/lib/libmfx.so.1 (0x00007efee8e00000)
        libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007efee8bd6000)
        libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007efee94bb000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007efee89ae000)
        libmvec.so.1 => /lib/x86_64-linux-gnu/libmvec.so.1 (0x00007efee9103000)
        libva-drm.so.2 => /usr/local/lib/libva-drm.so.2 (0x00007efee8600000)
        /lib64/ld-linux-x86-64.so.2 (0x00007efeee093000)
        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007efee94b4000)
        libdrm.so.2 => /lib/x86_64-linux-gnu/libdrm.so.2 (0x00007efee949e000)
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
    --enable-libfontconfig --enable-libass --enable-libaribb24 --enable-sdl2 --enable-cuda-llvm
    --enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc --enable-libmfx --enable-d3d11va
    --enable-dxva2 --arch=x86_64 --cross-prefix=x86_64-w64-mingw32- --disable-autodetect --disable-debug
    --disable-doc --disable-w32threads --enable-cross-compile --enable-gpl --enable-version3
    --extra-libs='-static -static-libgcc -static-libstdc++ -Wl,-Bstatic -lm -lpthread -lstdc++'
    --extra-cflags=--static --target-os=mingw64 --pkg-config=pkg-config --pkg-config-flags=--static -prefix=/usr/local
    ```
    </details>

    <details>
    <summary>Dependent library</summary>

    ```bat
    > dumpbin /Dependents ffmpeg-5.1.2-windows-x64\ffmpeg.exe
    Microsoft (R) COFF/PE Dumper Version 14.34.31937.0
    Copyright (C) Microsoft Corporation.  All rights reserved.


    Dump of file ffmpeg-5.1.2-windows-x64\ffmpeg.exe

    File Type: EXECUTABLE IMAGE

      Image has the following dependencies:

        ADVAPI32.dll
        bcrypt.dll
        CRYPT32.dll
        GDI32.dll
        IMM32.dll
        KERNEL32.dll
        msvcrt.dll
        ole32.dll
        OLEAUT32.dll
        PSAPI.DLL
        SETUPAPI.dll
        SHELL32.dll
        SHLWAPI.dll
        USER32.dll
        VERSION.dll
        AVICAP32.dll
        WINMM.dll
        WS2_32.dll
        WSOCK32.dll

      Summary

            1000 .CRT
          864000 .bss
          25000 .data
            B000 .edata
            7000 .idata
          E4000 .pdata
          A19000 .rdata
          30000 .reloc
            1000 .rodata
        399B000 .text
            1000 .tls
          128000 .xdata
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
ffmpeg  ffplay  ffprobe
$ ls lib/*
lib/libigdgmm.so          lib/libmfx-gen.so.1.2.8  lib/libva-drm.so.2             lib/libva-x11.so
lib/libigdgmm.so.12       lib/libmfx.so            lib/libva-drm.so.2.1700.0      lib/libva-x11.so.2
lib/libigdgmm.so.12.3.0   lib/libmfx.so.1          lib/libva-glx.so               lib/libva-x11.so.2.1700.0
lib/libigfxcmrt.so        lib/libmfx.so.1.35       lib/libva-glx.so.2             lib/libva.so
lib/libigfxcmrt.so.7      lib/libmfxhw64.so        lib/libva-glx.so.2.1700.0      lib/libva.so.2
lib/libigfxcmrt.so.7.2.0  lib/libmfxhw64.so.1      lib/libva-wayland.so           lib/libva.so.2.1700.0
lib/libmfx-gen.so         lib/libmfxhw64.so.1.35   lib/libva-wayland.so.2
lib/libmfx-gen.so.1.2     lib/libva-drm.so         lib/libva-wayland.so.2.1700.0

lib/dri:
iHD_drv_video.so
$ cat run.sh
#!/bin/sh
export PATH=$(dirname $0)/bin:$PATH
export LD_LIBRARY_PATH=$(dirname $0)/lib:$LD_LIBRARY_PATH
export LIBVA_DRIVERS_PATH=$(dirname $0)/lib/dri
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
> $Env:CUDA_SDK_VERSION = "12.0.1"
> $Env:NVIDIA_DRIVER_VERSION = "528.33"
> curl -L -o cuda_${Env:CUDA_SDK_VERSION}_${Env:NVIDIA_DRIVER_VERSION}_windows.exe https://developer.download.nvidia.com/compute/cuda/${Env:CUDA_SDK_VERSION}/local_installers/cuda_${Env:CUDA_SDK_VERSION}_${Env:NVIDIA_DRIVER_VERSION}_windows.exe
> docker buildx build --build-arg HOST_TARGET=x86_64-w64-mingw32 --build-arg TARGET_OS=windows --build-arg CUDA_SDK_VERSION=${Env:CUDA_SDK_VERSION} --build-arg NVIDIA_DRIVER_VERSION=${Env:NVIDIA_DRIVER_VERSION} --output type=local,dest=build -t ffmpeg-nonfree:windows -f ./nonfree.Dockerfile .
```

```bash
# for linux build
$ touch cuda_11.6.0_511.23_windows.exe # dummy file
$ docker buildx build --output type=local,dest=build -t ffmpeg-nonfree:linux -f ./nonfree.Dockerfile .
```

# Technical information

To execute QSV (Quick Sync Video) on a Virtual Machine, it is necessary to pass through Intel's integrated GPU (iGPU) to the VM.

Pass-through technologies include Intel GVT-g, SR-IOV, etc., and the compatibility varies depending on the generation of the CPU[^1].

For Intel GVT-g, please refer to the ArchWiki[^2].

In Proxmox, if you are using systemd-boot instead of GRUB, kernel parameters can be set using `/etc/kernel/cmdline`. Also, don't forget to apply the changes by running `proxmox-boot-tool refresh`. If necessary, adding `kvm.ignore_msrs=1` is recommended[^3].

[^1]: [Graphics Virtualization Technologies Support for Each Intel® Graphics Family](https://www.intel.com/content/www/us/en/support/articles/000093216/graphics/processor-graphics.html)

[^2]:https://wiki.archlinux.org/title/Intel_GVT-g

[^3]:https://kagasu.hatenablog.com/entry/2021/01/29/111659