#!/bin/bash
# Builds the ready-to-play Mac package: DBZ_BT4.app (and DBZ_BT4_Mac.zip next to it). Like windows/make_dist.ps1 it has
# no ISO, ELF or disc data: the app copies the ELF out of the player's ISO the first time.
# The Mac game runs only on the runtime's own renderer (seamvk on MoltenVK + MetalFX): no PCSX2 GS host in the package.
#   Contents/MacOS/      DBZ_BT4 (launcher)
#   Contents/Helpers/    Game.app: ps2EntryRunner (the recompiled game), a UI element (no Dock icon)
#   Contents/Frameworks/ the runner's dylibs, rewritten to load from here, and libMoltenVK.dylib (the native
#                        renderer's Vulkan; the launcher hands its path to the runner)
#   Contents/Resources/  runtime/ (assets, fps60_sites.txt, settings.toml), AppIcon.icns
# Inputs (see the README's "Native macOS" section):
#   RUNNER  the runner built for macOS 14 (macos/build_runner.sh: bt3mod-native/build-native, CMAKE_OSX_DEPLOYMENT_TARGET=14.0,
#           static minimal FFmpeg) with the native renderer (seamvk + MetalFX)
#   MVK     MoltenVK's dylib (default Homebrew's molten-vk; it links only system frameworks)
# Usage: macos/make_dist.sh [version]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R=~/NBAStreetRecomp
VERSION="${1:-1.0}"
RUNNER="${RUNNER:-$R/bt3mod-native/build-native/ps2xRuntime}"
MVK="${MVK:-/opt/homebrew/lib/libMoltenVK.dylib}"
OUT="${OUT:-$R/dbz/macdist}"
APP="$OUT/DBZ_BT4.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources/runtime"
C="$APP/Contents"
sed "s/@VERSION@/$VERSION/g" "$HERE/Info.plist" > "$C/Info.plist"

# executables
# the runner goes in a helper app with LSUIElement: no Dock icon for a process without a window of its own
G="$C/Helpers/Game.app/Contents/MacOS"
mkdir -p "$G"
cat > "$C/Helpers/Game.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>ps2EntryRunner</string>
	<key>CFBundleIdentifier</key><string>io.github.recomp-code.dbz-bt4.game</string>
	<key>CFBundleName</key><string>DBZ BT4</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
"$HERE/build_launcher.sh" "$C/MacOS/DBZ_BT4"
cp "$RUNNER/ps2EntryRunner" "$G/"
strip -x "$G/ps2EntryRunner"
# [native] the native renderer's Vulkan driver: MoltenVK, opened by path (the launcher sets GRANITE_VULKAN_LIBRARY)
cp -L "$MVK" "$C/Frameworks/libMoltenVK.dylib"
chmod u+w "$C/Frameworks/libMoltenVK.dylib"
install_name_tool -id "@executable_path/../Frameworks/libMoltenVK.dylib" "$C/Frameworks/libMoltenVK.dylib"

# dylibs: everything outside the system, recursively, loaded from Contents/Frameworks
fix_refs() {   # fix_refs <binary>: point its non-system dylib references at Frameworks/
    { otool -L "$1" | tail -n +2 | awk '{print $1}' | grep -E '^/(opt|usr/local|Users)/' || true; } | while read -r dep; do
        install_name_tool -change "$dep" "@executable_path/../Frameworks/$(basename "$dep")" "$1" 2>/dev/null
    done
}
# copy each referenced install name (the name the binaries ask for, e.g. libSDL3.0.dylib) until nothing new shows up
while :; do
    added=0
    for bin in "$G/ps2EntryRunner" "$C"/Frameworks/*.dylib; do
        [ -f "$bin" ] || continue
        for dep in $(otool -L "$bin" | tail -n +2 | awk '{print $1}' | grep -E '^/(opt|usr/local|Users)/'); do
            name="$(basename "$dep")"
            if [ ! -f "$C/Frameworks/$name" ]; then
                cp -L "$dep" "$C/Frameworks/$name"
                chmod u+w "$C/Frameworks/$name"
                install_name_tool -id "@executable_path/../Frameworks/$name" "$C/Frameworks/$name" 2>/dev/null
                added=1
            fi
        done
    done
    [ $added = 0 ] && break
done
for bin in "$G/ps2EntryRunner" "$C"/Frameworks/*.dylib; do
    [ -f "$bin" ] && fix_refs "$bin"
done
if otool -L "$C/MacOS/"* "$G/"* "$C"/Frameworks/*.dylib 2>/dev/null | grep -E '^\s/(opt|usr/local|Users)/'; then
    echo "a binary still loads a library from this Mac (above)" >&2; exit 1
fi

# resources: the runtime's
cp -R "$RUNNER/assets" "$C/Resources/runtime/assets"
# [pipewarm] the pipelines the native renderer uses (recorded over fights at 30 / 60 fps, windowed and fullscreen, and
# the menus): built in the background at start, so a fresh install does not stop at each effect's first appearance
cp "$HERE/seamvk_pipelines.bin" "$C/Resources/runtime/assets/seamvk_pipelines.bin"
cp "$RUNNER/fps60_sites.txt" "$C/Resources/runtime/"
cp "$HERE/settings.toml" "$C/Resources/runtime/settings.toml"
# icon: the runtime's icon.png
ICON="$OUT/AppIcon.iconset"
rm -rf "$ICON"; mkdir -p "$ICON"
for s in 16 32 128 256 512; do
    sips -z $s $s "$RUNNER/assets/icon.png" --out "$ICON/icon_${s}x${s}.png" > /dev/null
    sips -z $((s * 2)) $((s * 2)) "$RUNNER/assets/icon.png" --out "$ICON/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns "$ICON" -o "$C/Resources/AppIcon.icns"
rm -rf "$ICON"

cp "$HERE/LEEME.txt" "$OUT/LEEME.txt"

# ad-hoc signature, inside out (Apple Silicon refuses unsigned code)
codesign --force -s - "$C"/Frameworks/*.dylib
codesign --force -s - "$G/ps2EntryRunner"
codesign --force -s - "$C/Helpers/Game.app"
codesign --force -s - "$APP"
codesign --verify --deep --strict "$APP"

du -sh "$APP"
if [ "${NOZIP:-0}" != 1 ]; then
    rm -f "$OUT/DBZ_BT4_Mac.zip"
    (cd "$OUT" && ditto -c -k --sequesterRsrc --keepParent DBZ_BT4.app DBZ_BT4_Mac.zip.tmp && \
        zip -q DBZ_BT4_Mac.zip.tmp LEEME.txt && mv DBZ_BT4_Mac.zip.tmp DBZ_BT4_Mac.zip)
    du -sh "$OUT/DBZ_BT4_Mac.zip"
fi
