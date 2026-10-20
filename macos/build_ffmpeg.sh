#!/bin/bash
# build_ffmpeg.sh: minimal static FFmpeg 7.1 (LGPL) for the distributed runner: the game's MPEG-2 movies plus the usual
# formats of replacement videos. Homebrew's FFmpeg only loads on the macOS it was built for and pulls ~25 dylibs.
# -> ~/NBAStreetRecomp/dbz/macdist/ffmpeg (PKG_CONFIG_PATH=<that>/lib/pkgconfig for build_runner.sh)
set -e
OUT=~/NBAStreetRecomp/dbz/macdist
VER=7.1.2
mkdir -p "$OUT" && cd "$OUT"
[ -f ffmpeg-$VER.tar.xz ] || curl -fLO https://ffmpeg.org/releases/ffmpeg-$VER.tar.xz
rm -rf ffmpeg-src && mkdir ffmpeg-src && tar xf ffmpeg-$VER.tar.xz -C ffmpeg-src --strip-components=1
cd ffmpeg-src
export MACOSX_DEPLOYMENT_TARGET=14.0
./configure --prefix="$OUT/ffmpeg" --enable-static --disable-shared --disable-programs --disable-doc --disable-network \
    --disable-autodetect --disable-everything --enable-pic \
    --enable-decoder=mpeg1video,mpeg2video,h264,hevc,mpeg4,vp8,vp9,aac,mp3,mp2,opus,vorbis,flac,pcm_s16le,pcm_s16be,adpcm_psx \
    --enable-demuxer=mpegps,mpegvideo,mov,matroska,avi,mp3,wav,ogg,h264,hevc,m4v,aac,flac \
    --enable-parser=mpegvideo,h264,hevc,mpeg4video,vp8,vp9,aac,mpegaudio,opus,vorbis,flac \
    --enable-protocol=file --enable-swscale --enable-swresample \
    --extra-cflags="-mmacosx-version-min=14.0" --extra-ldflags="-mmacosx-version-min=14.0"
nice -n 19 make -j6
make install
