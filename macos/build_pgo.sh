#!/bin/bash
# [pgo] The Mac runner built with clang's profile (same as windows/build_pgo.cmd), in its own build folders:
#   build_pgo.sh gen   -> build-pgo-gen: instrumented (-fprofile-instr-generate); play the training fight with
#                         LLVM_PROFILE_FILE=<bt3mod>/pgo/pgo-%p.profraw and PS2X_PGO_WRITE_AT=<seconds> (writes the profile)
#   build_pgo.sh use   -> merges pgo/*.profraw into pgo/runner.profdata and builds build-pgo with it (make_dist.sh:
#                         RUNNER=<bt3mod>/build-pgo/ps2xRuntime). The profile comes from the code generated from your ELF: it
#                         stays on your disk, it is not uploaded. A Windows profile does not fit ARM: train on the Mac.
# Same configuration as build_runner.sh (macOS 14, static minimal FFmpeg, system libraries only).
set -e
cd "${BT3MOD:-$HOME/NBAStreetRecomp/bt3mod-native}"
export PKG_CONFIG_PATH=~/NBAStreetRecomp/dbz/macdist/ffmpeg/lib/pkgconfig
export MACOSX_DEPLOYMENT_TARGET=14.0
P="$PWD/pgo"
common=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DPS2X_ENABLE_SCCACHE=OFF -DPS2X_FORCE_PGS=ON
    -DENABLE_LZ4=OFF -DENABLE_ZSTD=OFF -DENABLE_LIBB2=OFF -DENABLE_OPENSSL=OFF -DENABLE_EXPAT=OFF
    -DENABLE_LIBXML2=OFF -DENABLE_ICONV=OFF -DENABLE_BZip2=OFF)
case "$1" in
gen)
    mkdir -p "$P"
    cmake -S . -B build-pgo-gen "${common[@]}" \
        "-DCMAKE_C_FLAGS=-fprofile-instr-generate -DPS2X_PGO_GEN" "-DCMAKE_CXX_FLAGS=-fprofile-instr-generate -DPS2X_PGO_GEN" \
        "-DCMAKE_EXE_LINKER_FLAGS=-fprofile-instr-generate"
    nice -n 19 cmake --build build-pgo-gen --target ps2EntryRunner -j6
    ;;
use)
    xcrun llvm-profdata merge -o "$P/runner.profdata" "$P"/*.profraw
    f="-fprofile-instr-use=$P/runner.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin"
    cmake -S . -B build-pgo "${common[@]}" "-DCMAKE_C_FLAGS=$f" "-DCMAKE_CXX_FLAGS=$f"
    nice -n 19 cmake --build build-pgo --target ps2EntryRunner -j6
    ;;
*)
    echo "usage: build_pgo.sh gen | use" >&2; exit 9
    ;;
esac
