#!/bin/bash
# build_runner.sh: the runner for the Mac package (bt3mod/build-mac-dist): macOS 14+, static FFmpeg (build_ffmpeg.sh),
# libarchive without Homebrew's lz4/zstd/libb2, so ps2EntryRunner loads only system libraries.
# The bt3mod tree is BT3-Recomp e22a34b + patches/bt3recomp-bt4mod-full.patch + bt3recomp-bt4mod-windows.patch +
# bt3recomp-bt4mod-macos.patch + bt3recomp-bt4mod-perf.patch + bt3recomp-bt4mod-unlock.patch
# + bt3recomp-bt4mod-netstats.patch + bt3recomp-bt4mod-movieend.patch + bt3recomp-bt4mod-livebatch.patch
# + bt3recomp-bt4mod-perf2.patch + bt3recomp-bt4mod-seamperf.patch, with the game code generated as in the README's
# "Native macOS" section.
# (The Mac GS host takes pcsx2-gsrunner-perf2.patch too: its Vulkan budget fix and PS2X_HWDOWNLOAD_MODE are shared code.)
set -e
cd ~/NBAStreetRecomp/bt3mod
export PKG_CONFIG_PATH=~/NBAStreetRecomp/dbz/macdist/ffmpeg/lib/pkgconfig
export MACOSX_DEPLOYMENT_TARGET=14.0
cmake -S . -B build-mac-dist -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DPS2X_ENABLE_SCCACHE=OFF -DPS2X_FORCE_PGS=ON \
    -DENABLE_LZ4=OFF -DENABLE_ZSTD=OFF -DENABLE_LIBB2=OFF -DENABLE_OPENSSL=OFF -DENABLE_EXPAT=OFF \
    -DENABLE_LIBXML2=OFF -DENABLE_ICONV=OFF -DENABLE_BZip2=OFF "$@"
nice -n 19 cmake --build build-mac-dist --target ps2EntryRunner -j6
