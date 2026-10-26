#!/bin/bash
# build_runner.sh [plain|gen|use]: the recompiled game as libmain.so for android-arm64, from BT3MOD (default
# ~/NBAStreetRecomp/bt3mod-android: the Mac native tree -- see macos/build_runner.sh for its patch chain -- plus
# patches/bt3recomp-bt4mod-android.patch). SDL's Java activity loads it and calls SDL_main (android_main.cpp).
#   plain -> build-android       no profile
#   gen   -> build-android-gen   instrumented: run the training (PS2X_PGO_WRITE_AT=<s>; the profile lands in the app's
#                                external files dir as pgo-<pid>.profraw), adb pull it into $WORK/pgo/
#   use   -> build-android-pgo   with $WORK/pgo/runner.profdata (merged from the .profraw files). Train on a phone: the
#                                profile follows the code, which comes from your ELF -- it stays on your disk.
# ARMv8.2-A (+fp16, dotprod): every phone that can run the game (2018 and later).
set -e
WORK="${ANDROID_WORK:-$HOME/NBAStreetRecomp/android}"
NDK="${ANDROID_NDK:-$HOME/Library/Android/sdk/ndk/28.2.13676358}"
TC=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin
MODE=${1:-plain}
cd "${BT3MOD:-$HOME/NBAStreetRecomp/bt3mod-android}"
L="-L$WORK/ffmpeg/lib -L$WORK/libstub"
ARCH="-march=armv8.2-a+fp16+dotprod"
case $MODE in
plain) B=build-android; F="$ARCH" ;;
gen)   B=build-android-gen; F="$ARCH -fprofile-instr-generate -DPS2X_PGO_GEN"; L="$L -fprofile-instr-generate" ;;
use)   B=build-android-pgo; $TC/llvm-profdata merge -o "$WORK/pgo/runner.profdata" "$WORK"/pgo/*.profraw
       F="$ARCH -fprofile-instr-use=$WORK/pgo/runner.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin" ;;
*) echo "usage: build_runner.sh plain|gen|use" >&2; exit 9 ;;
esac
PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR="$WORK/ffmpeg/lib/pkgconfig" cmake -S . -B $B -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=31 \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DPS2X_ENABLE_SCCACHE=OFF -DPS2X_FORCE_PGS=ON \
    -DENABLE_LZ4=OFF -DENABLE_ZSTD=OFF -DENABLE_LIBB2=OFF -DENABLE_OPENSSL=OFF -DENABLE_EXPAT=OFF -DENABLE_LIBXML2=OFF \
    -DENABLE_ICONV=OFF -DENABLE_BZip2=OFF -DPKG_CONFIG_EXECUTABLE="$(which pkg-config)" \
    "-DCMAKE_C_FLAGS=$F" "-DCMAKE_CXX_FLAGS=$F" "-DCMAKE_EXE_LINKER_FLAGS=$L" "-DCMAKE_SHARED_LINKER_FLAGS=$L" > "$WORK/configure-$MODE.log"
nice -n 19 cmake --build $B --target ps2EntryRunner -j10
