# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds FFmpeg binaries with extensive codec support for Linux, Windows, and macOS platforms. It uses Docker for Linux/Windows builds and native macOS runners for Apple Silicon builds. The builds include hardware acceleration support (NVIDIA CUDA, Intel QSV/VAAPI, Apple VideoToolbox).

## Build System Architecture

### Multi-Stage Docker Build Pattern

The Dockerfile uses a multi-stage build with distinct stages:

1. **build-env**: Base Ubuntu 22.04 environment with all build tools (clang, cmake, meson, mingw-w64, etc.)
2. **ffmpeg-linux-build**: Builds all third-party libraries and Linux FFmpeg binary in a single stage
3. **ffmpeg-linux**: Final Ubuntu-based image with FFmpeg and runtime libraries
4. **ffmpeg-windows-build**: Builds all third-party libraries and Windows FFmpeg binary in a single stage
5. **ffmpeg-windows**: Scratch image with Windows FFmpeg binaries
6. **ffmpeg-linux-export**: Exports Linux binaries for release artifacts
7. **ffmpeg-windows-export**: Exports Windows binaries for release artifacts
8. **vainfo-build/vainfo**: Builds vainfo utility (references external ffmpeg-library image for dependencies)

### Script Organization (OS-Separated Structure)

Scripts are organized by OS in `scripts/` directory:

```
scripts/
├── common/          # Shared helper functions and build tools
│   ├── helpers.sh         # Core functions: download_and_unpack_file, git_clone, mkcd, gen_implib, do_strip, cp_archive
│   │                      # BSD/GNU compatibility: do_strip uses -perm +111 on macOS, cp_archive uses rsync on macOS
│   ├── build-tools.sh     # Build wrappers: do_configure, do_cmake, do_meson, do_make_and_make_install
│   └── versions.sh        # (Future) Centralized version definitions
├── linux/           # Linux-specific scripts
│   ├── base.sh            # Linux environment setup (CFLAGS, LDFLAGS, toolchain config)
│   └── build.sh           # Integrated build: libraries + FFmpeg (includes libdrm, libva, media-driver, etc.)
├── windows/         # Windows cross-compilation scripts
│   ├── base.sh            # mingw-w64 cross-compilation setup
│   └── build.sh           # Integrated build: libraries + FFmpeg (excludes Linux-specific hardware accel libs)
└── macos/           # macOS native build scripts
    ├── base.sh            # macOS environment setup
    └── build.sh           # Integrated build script (libraries + FFmpeg with VideoToolbox)
```

**Key Design Principles:**
- Each OS has independent base.sh that sources common scripts and sets OS-specific environment
- Linux-only libraries: libpciaccess, libdrm, libva, gmmlib, media-driver, intel-vaapi-driver, oneVPL-intel-gpu, MediaSDK
- Windows-only: MFX_dispatch, d3d11va/dxva2 support
- All scripts use `FFMPEG_CONFIGURE_OPTIONS` array to build FFmpeg configure flags
- Shared libraries built with static linking where possible for portability

**BSD/GNU Compatibility (macOS Native Builds):**
- `do_strip()`: Uses `-perm +111` instead of `-executable` on BSD find (macOS)
- `cp_archive()`: Uses `rsync -a --relative` instead of GNU cp's `--archive --parents` on macOS
- All helper functions in `scripts/common/helpers.sh` check `$HOST_OS` for platform-specific behavior
- macOS builds use `/usr/bin/find` and `/usr/bin/rsync` explicitly to avoid GNU tools from Homebrew

### Implib.so for Dynamic Library Delay-Loading

Linux builds use [Implib.so](https://github.com/yugr/Implib.so) to create static wrapper libraries for dynamic dependencies (libva, libdrm, libmfx). This allows FFmpeg to run without hardware acceleration libraries present, loading them only when QSV/VAAPI is used. See `gen_implib()` function in `scripts/common/helpers.sh`.

## Build Commands

### Docker Builds

```bash
# Build Linux FFmpeg (builds libraries and FFmpeg in a single stage)
docker build --target ffmpeg-linux --tag ffmpeg:linux .

# Build Windows FFmpeg (builds libraries and FFmpeg in a single stage)
docker build --target ffmpeg-windows --tag ffmpeg-win .

# Build with specific FFmpeg version
docker build --build-arg FFMPEG_VERSION=6.1.2 --target ffmpeg-linux .

# Build vainfo utility
docker build --target vainfo --tag vainfo .

# Export binaries locally
docker buildx build --target ffmpeg-linux-export --output type=local,dest=./build .
docker buildx build --target ffmpeg-windows-export --output type=local,dest=./build .
```

### macOS Native Build

```bash
# Full build (runs on Apple Silicon, integrates library build and FFmpeg build)
./scripts/macos/build.sh

# With specific FFmpeg version
FFMPEG_VERSION=7.0.2 ./scripts/macos/build.sh

# Build output location (defined in base.sh)
# - Binaries: /tmp/dist/opt/ffmpeg/bin/
# - Build artifacts: /tmp/ffmpeg-build/
```

## GitHub Actions Workflows

### Workflow Triggers

Each platform has its own independent workflow for better isolation and parallel execution:

- **ffmpeg-linux.yml**: Linux FFmpeg builds
  - Triggered by: workflow_dispatch, push to tags (v*)
  - Matrix: FFmpeg versions `[8.0, 7.0.2, 6.1.2, 5.1.6]`
  - Actions:
    - Builds third-party libraries and FFmpeg in a single Docker stage
    - Pushes final images to Docker Hub: `akashisn/ffmpeg:{version}`
    - Exports binaries using `ffmpeg-linux-export` target
    - Creates tar.xz archives: `ffmpeg-{version}-linux-amd64.tar.xz`
    - Uploads artifacts to GitHub Actions (for release workflow)

- **ffmpeg-windows.yml**: Windows FFmpeg builds (cross-compiled on Ubuntu)
  - Triggered by: workflow_dispatch, push to tags (v*)
  - Matrix: FFmpeg versions `[8.0, 7.0.2, 6.1.2, 5.1.6]`
  - Actions:
    - Builds third-party libraries and FFmpeg in a single Docker stage
    - Pushes final images to GHCR: `ghcr.io/akashisn/ffmpeg-windows:{version}`
    - Exports binaries using `ffmpeg-windows-export` target
    - Creates tar.xz archives: `ffmpeg-{version}-windows-x64.tar.xz`
    - Uploads artifacts to GitHub Actions (for release workflow)

- **ffmpeg-macos.yml**: macOS native builds (Apple Silicon)
  - Triggered by: workflow_dispatch, push to tags (v*)
  - Matrix: FFmpeg versions `[8.0, 7.0.2, 6.1.2, 5.1.6]`
  - Runs on `macos-26` runner
  - Actions:
    - Builds FFmpeg natively with VideoToolbox support
    - Creates tar.xz archives: `ffmpeg-{version}-macos-arm64.tar.xz`
    - Uploads artifacts to GitHub Actions (for release workflow)
  - Build script receives FFMPEG_VERSION environment variable

- **vainfo.yml**: Utility for checking Intel QSV/VAAPI support (Linux only)
  - Triggered by workflow_dispatch
  - Builds vainfo utility image

- **ffmpeg-release.yml**: Release workflow (manual trigger only)
  - Triggered by: workflow_dispatch (manual trigger only)
  - Prerequisites:
    - Current commit must be tagged with a version tag (starting with 'v')
    - All three platform workflows (Linux/Windows/macOS) must have completed successfully for this tag
  - Actions:
    - Verifies current commit is tagged
    - Checks that all three platform workflows succeeded for this tag (filters by both commit SHA and tag name)
    - Downloads artifacts from all three platform workflows using gh CLI
    - Creates GitHub release with all tar.xz archives attached
  - No building occurs in this workflow; it only aggregates and publishes artifacts
  - Safety: Filters workflow runs by both `head_sha` (commit) and `head_branch` (tag name) to ensure only artifacts from the correct tag are used, preventing accidental inclusion of builds from other branches

### Workflow Dependencies

```
Tag Push (v*)
    ↓ (parallel)
    ├── ffmpeg-linux (builds & uploads artifacts)
    ├── ffmpeg-windows (builds & uploads artifacts)
    └── ffmpeg-macos (builds & uploads artifacts)
    ↓ (all complete successfully)
Manual trigger: workflow_dispatch on ffmpeg-release
    ├─ Verifies current commit is tagged
    ├─ Checks all 3 workflows succeeded
    └─ Downloads artifacts & creates GitHub release
```

The release workflow is manually triggered after confirming all platform builds have completed successfully. It verifies prerequisites before creating the release.

All platform workflows use Docker layer caching (type=gha) for faster builds (Linux/Windows only; macOS builds natively).

## Important Technical Details

### FFmpeg Version Compatibility

- **FFmpeg 6.0+**: Uses `--enable-libvpl` (oneVPL) for Intel QSV support
- **FFmpeg 5.x and earlier**: Uses `--enable-libmfx` (legacy MediaSDK)

The `build-ffmpeg.sh` scripts automatically detect version and adjust configuration. See version comparison logic in `scripts/{linux,windows}/build-ffmpeg.sh`.

### Hardware Acceleration Support

**Linux:**
- NVIDIA CUDA (nvenc/nvdec/cuvid) via nv-codec-headers
- Intel QSV via oneVPL → oneVPL-intel-gpu/MediaSDK
- Intel VAAPI via libva + media-driver/intel-vaapi-driver

**Windows:**
- NVIDIA CUDA (same as Linux)
- Intel QSV via libvpl/libmfx
- DirectX (d3d11va, dxva2)

**macOS:**
- Apple VideoToolbox (hardware H.264/H.265 encode/decode)

### Cross-Compilation for Windows

Windows builds use mingw-w64 toolchain on Ubuntu. Key environment variables in `scripts/windows/base.sh`:
- `CROSS_PREFIX=x86_64-w64-mingw32-`
- `BUILD_TARGET=x86_64-w64-mingw32`
- Meson cross-file: `${WORKDIR}/${BUILD_TARGET}.txt`
- CMake toolchain: `${WORKDIR}/toolchains.cmake`

### Library Building Pattern

All platform `build.sh` scripts follow this pattern for library building:
1. Build dependencies in correct order (e.g., libogg before vorbis)
2. Use static libraries where possible (`--enable-static --disable-shared`)
3. Accumulate FFmpeg configure options in `FFMPEG_CONFIGURE_OPTIONS` array
4. Save configure options and extra libs to PREFIX for FFmpeg configure:
   ```bash
   echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options
   echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${PREFIX}/ffmpeg_extra_libs
   ```
5. Build FFmpeg using the accumulated options in the same script

### Modifying Build Scripts

Each platform has a unified build script that handles both library building and FFmpeg configuration:

When adding/modifying libraries:

1. **Add to common libraries**: Edit library sections in `scripts/linux/build.sh` and `scripts/windows/build.sh`
2. **OS-specific libraries**: Add only to relevant OS script (e.g., libva → Linux only)
3. **Update configure options**: Add `FFMPEG_CONFIGURE_OPTIONS+=("--enable-libname")`
4. **Test both OS builds**: Ensure cross-compilation doesn't break
5. **Version updates**: Currently hardcoded in build.sh files (future: move to versions.sh)

When modifying FFmpeg configure:
- Linux: Edit FFmpeg configure section in `scripts/linux/build.sh`
- Windows: Edit FFmpeg configure section in `scripts/windows/build.sh` (add cross-compile specific flags)
- macOS: Edit FFmpeg configure section in `scripts/macos/build.sh` (minimal build, VideoToolbox only)

### Docker Layer Caching Strategy

GitHub Actions uses `cache-from: type=gha` and `cache-to: type=gha,mode=max` for Docker layer caching. Each platform's build stages are cached independently, allowing faster incremental builds when only specific components change.

## Testing Locally

```bash
# Test Linux FFmpeg build (includes libraries and FFmpeg)
docker build --target ffmpeg-linux --tag test:ffmpeg .

# Test Windows FFmpeg build
docker build --target ffmpeg-windows --tag test:ffmpeg-win .

# Test if configure options match previous build
docker run test:ffmpeg cat /usr/local/configure_options > new_options.txt
# Compare with expected configure_options from README.md

# Test vainfo build
docker build --target vainfo --tag test:vainfo .

# Test macOS build
./scripts/macos/build.sh
/tmp/dist/opt/ffmpeg/bin/ffmpeg -version
/tmp/dist/opt/ffmpeg/bin/ffmpeg -hwaccels  # Should show videotoolbox
```

## Release Process

1. Tag the commit with version tag: `git tag v1.0.0 && git push origin v1.0.0`
2. Three platform workflows trigger automatically in parallel:
   - `ffmpeg-linux.yml` builds all FFmpeg versions for Linux
   - `ffmpeg-windows.yml` builds all FFmpeg versions for Windows
   - `ffmpeg-macos.yml` builds all FFmpeg versions for macOS
3. Each platform workflow:
   - Builds FFmpeg binaries
   - Pushes Docker images (Linux/Windows only)
   - Exports binaries and creates tar.xz archives
   - Uploads artifacts to GitHub Actions
4. Wait for all three platform workflows to complete successfully
5. Manually trigger `ffmpeg-release.yml` workflow:
   - Navigate to Actions tab on GitHub
   - Select "ffmpeg-release" workflow
   - Click "Run workflow" button
   - The workflow will:
     - Verify the current commit is tagged with a version tag (v*)
     - Check that all three platform workflows succeeded for this commit
     - Download all artifacts from the successful builds using gh CLI
     - Create GitHub release with all tar.xz archives:
       - `ffmpeg-{version}-linux-amd64.tar.xz` (multiple versions)
       - `ffmpeg-{version}-windows-x64.tar.xz` (multiple versions)
       - `ffmpeg-{version}-macos-arm64.tar.xz` (multiple versions)

Archives contain: `bin/`, `lib/`, `configure_options`, and `run.sh` (Linux only) for setting LD_LIBRARY_PATH.
