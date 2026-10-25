#!/bin/bash
# build_runner.sh: the runner for the Mac package (bt3mod-native/build-native): macOS 14+, static FFmpeg (build_ffmpeg.sh),
# libarchive without Homebrew's lz4/zstd/libb2, so ps2EntryRunner loads only system libraries.
# The bt3mod tree is BT3-Recomp e22a34b + patches/bt3recomp-bt4mod-full.patch + bt3recomp-bt4mod-windows.patch +
# bt3recomp-bt4mod-macos.patch + bt3recomp-bt4mod-perf.patch + bt3recomp-bt4mod-unlock.patch
# + bt3recomp-bt4mod-netstats.patch + bt3recomp-bt4mod-movieend.patch + bt3recomp-bt4mod-livebatch.patch
# + bt3recomp-bt4mod-perf2.patch + bt3recomp-bt4mod-seamperf.patch + bt3recomp-bt4mod-glshare.patch + bt3recomp-bt4mod-upscale.patch + bt3recomp-bt4mod-fsr2.patch + bt3recomp-bt4mod-netnative.patch + bt3recomp-bt4mod-descfix.patch + bt3recomp-bt4mod-parity.patch + bt3recomp-bt4mod-pacing.patch + bt3recomp-bt4mod-metalfx.patch + bt3recomp-bt4mod-maskpc.patch, with the game code generated as in the README's
# "Native macOS" section. The tree is bt3mod-native (BT3MOD= overrides): there, full.patch goes in without
# ps2xRuntime/third_party/parallel-gs (it keeps parallel-gs-moltenvk / granite-moltenvk), and the native renderer
# (seamvk) needs Granite's volk and khronos/vulkan-headers. One runner for both: the PCSX2 host qualities and the
# native renderer with MetalFX.
# (The Mac GS host takes pcsx2-gsrunner-perf2.patch too: its Vulkan budget fix and PS2X_HWDOWNLOAD_MODE are shared code.)
set -e
cd "${BT3MOD:-$HOME/NBAStreetRecomp/bt3mod-native}"
export PKG_CONFIG_PATH=~/NBAStreetRecomp/dbz/macdist/ffmpeg/lib/pkgconfig
export MACOSX_DEPLOYMENT_TARGET=14.0
cmake -S . -B build-native -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DPS2X_ENABLE_SCCACHE=OFF -DPS2X_FORCE_PGS=ON \
    -DENABLE_LZ4=OFF -DENABLE_ZSTD=OFF -DENABLE_LIBB2=OFF -DENABLE_OPENSSL=OFF -DENABLE_EXPAT=OFF \
    -DENABLE_LIBXML2=OFF -DENABLE_ICONV=OFF -DENABLE_BZip2=OFF "$@"
nice -n 19 cmake --build build-native --target ps2EntryRunner -j6
