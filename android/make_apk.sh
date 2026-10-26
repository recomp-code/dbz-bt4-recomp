#!/bin/bash
# make_apk.sh [debug|release] [runner build dir]: the Android app (project/), ready to install.
#   libmain.so      the runner (build_runner.sh: build-android-pgo when it exists, else build-android), stripped
#   liblauncher.so  recomp-online's Go launcher (launcher/*_android.go) with the online server built in
#   assets/launcher the launcher's frontend + android_bridge.js (its Wails runtime) + android.css (the phone layout)
#   assets/runtime  the runtime's assets, fps60_sites.txt, settings.toml (window_mode 2) and the pipewarm seed
#   res/mipmap-*    the launcher icon, from the runtime's icon.png (make_icons.py, needs Pillow)
# No game data: the app reads what it needs from the player's ISO. Release builds are signed with $ANDROID_KEYSTORE
# (see project/app/build.gradle).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R=~/NBAStreetRecomp
MODE=${1:-debug}
SERVER=${RECOMP_SERVER:-https://nbas3.xellrecomp.party}
NDK="${ANDROID_NDK:-$HOME/Library/Android/sdk/ndk/28.2.13676358}"
TC=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin
B=${2:-}
if [ -z "$B" ]; then B=${BT3MOD:-$R/bt3mod-android}/build-android-pgo; [ -f $B/ps2xRuntime/libmain.so ] || B=${BT3MOD:-$R/bt3mod-android}/build-android; fi
APP=$HERE/project/app
LIBS=$APP/libs/arm64-v8a
mkdir -p $LIBS
echo "runner: $B"
$TC/llvm-strip --strip-unneeded -o $LIBS/libmain.so $B/ps2xRuntime/libmain.so
( cd ${RECOMP_ONLINE:-$R/recomp-online}/launcher && CGO_ENABLED=1 GOOS=android GOARCH=arm64 GOTOOLCHAIN=local \
    CC=$TC/aarch64-linux-android31-clang go build -buildmode=c-shared -trimpath \
    -ldflags "-s -w -X main.defaultServer=$SERVER" -o $LIBS/liblauncher.so . && rm -f $LIBS/liblauncher.h )
AS=$APP/src/main/assets
rm -rf $AS && mkdir -p $AS/launcher $AS/runtime
cp -R ${RECOMP_ONLINE:-$R/recomp-online}/launcher/frontend/. $AS/launcher/
cp $HERE/android_bridge.js $HERE/android.css $AS/launcher/
sed -i '' 's#<script src="app.js"></script>#<script src="android_bridge.js"></script>\n<script src="app.js"></script>#' $AS/launcher/index.html
sed -i '' 's#<link rel="stylesheet" href="style.css">#<link rel="stylesheet" href="style.css">\n<link rel="stylesheet" href="android.css">#' $AS/launcher/index.html
grep -q android_bridge.js $AS/launcher/index.html && grep -q android.css $AS/launcher/index.html
cp -R $B/ps2xRuntime/assets $AS/runtime/assets
cp $HERE/../macos/seamvk_pipelines.bin $AS/runtime/assets/seamvk_pipelines.bin
cp $B/ps2xRuntime/fps60_sites.txt $AS/runtime/
cp $HERE/settings.toml $AS/runtime/settings.toml
# the launcher icon from the runtime's icon.png (generated like the Mac app's: the art is not in the repository)
python3 -I $HERE/make_icons.py $B/ps2xRuntime/assets/icon.png $APP/src/main/res
cd $HERE/project
[ -f local.properties ] || echo "sdk.dir=${ANDROID_HOME:-$HOME/Library/Android/sdk}" > local.properties
export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}
if [ "$MODE" = release ]; then
    ./gradlew -q assembleRelease
    ls -la app/build/outputs/apk/release/*.apk
else
    ./gradlew -q assembleDebug
    ls -la app/build/outputs/apk/debug/*.apk
fi
