#!/bin/bash
# build_ffmpeg.sh: minimal static FFmpeg 7.1 (LGPL) for android-arm64, the same components as macos/build_ffmpeg.sh (the
# game's MPEG-2 movies plus the usual formats of replacement videos). -> $WORK/ffmpeg (build_runner.sh links it)
set -e
WORK="${ANDROID_WORK:-$HOME/NBAStreetRecomp/android}"
NDK="${ANDROID_NDK:-$HOME/Library/Android/sdk/ndk/28.2.13676358}"
TC=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin
VER=7.1.2
mkdir -p "$WORK" && cd "$WORK"
[ -f ffmpeg-$VER.tar.xz ] || curl -fLO https://ffmpeg.org/releases/ffmpeg-$VER.tar.xz
rm -rf ffmpeg-src && mkdir ffmpeg-src && tar xf ffmpeg-$VER.tar.xz -C ffmpeg-src --strip-components=1
cd ffmpeg-src
./configure --prefix="$WORK/ffmpeg" --enable-static --disable-shared --disable-programs --disable-doc --disable-network \
    --disable-autodetect --disable-everything --enable-pic \
    --target-os=android --arch=aarch64 --enable-cross-compile \
    --cc=$TC/aarch64-linux-android31-clang --cxx=$TC/aarch64-linux-android31-clang++ \
    --ar=$TC/llvm-ar --ranlib=$TC/llvm-ranlib --nm=$TC/llvm-nm --strip=$TC/llvm-strip \
    --enable-decoder=mpeg1video,mpeg2video,h264,hevc,mpeg4,vp8,vp9,aac,mp3,mp2,opus,vorbis,flac,pcm_s16le,pcm_s16be,adpcm_psx \
    --enable-demuxer=mpegps,mpegvideo,mov,matroska,avi,mp3,wav,ogg,h264,hevc,m4v,aac,flac \
    --enable-parser=mpegvideo,h264,hevc,mpeg4video,vp8,vp9,aac,mpegaudio,opus,vorbis,flac \
    --enable-protocol=file --enable-swscale --enable-swresample
nice -n 19 make -j6
make install
mkdir -p "$WORK/libstub" && $TC/llvm-ar rcs "$WORK/libstub/libpthread.a"   # bionic has pthread in libc: an empty -lpthread
