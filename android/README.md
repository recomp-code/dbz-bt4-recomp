# DBZ BT4 for Android

The recompiled game on Android (arm64, Android 12+, Vulkan 1.1): the same runtime and native renderer as the Mac build,
and the same Recomp launcher (recomp-online's Go code and frontend) in a WebView. No game data in the app: the player
picks their ISO with the system's document picker; it is read in place (a file descriptor), never copied.

## What is in it

- `../patches/bt3recomp-bt4mod-android.patch` - the runtime layer, on top of the Mac native tree (macos/build_runner.sh):
  - `android/android_main.cpp` - SDL_main: the launcher's environment, the log, the game's process end
  - `android/touch_pad.cpp` - on-screen controls (floating stick, D-pad, face buttons, shoulders, menu)
  - `android/gl_es_shim.cpp` - the GL 3.3 code on GLES 3.x (shader versions, dual-source blend, desktop entry points)
  - `android/perf_hint.cpp` - ADPF performance hints (the cores stayed at ~1 GHz without them)
  - `android/android_compat.h` - bionic gaps; `ps2_fiber.cpp` - an AArch64 context switch (no makecontext on Android)
  - `ps2_seamvk*.cpp` - [ahbshare] zero-copy frames to GL through AHardwareBuffers, classic descriptor sets (Adreno's
    descriptor-buffer path faults), the upscaler's output fit to a phone's screen
- `project/` - the app: `LauncherActivity` (WebView + `RecompBridge`, JNI into liblauncher.so), `GameActivity` (SDL's
  activity around libmain.so, process `:game`), `GameService` (keeps the online session alive while playing)
- `android_bridge.js` / `android.css` - the frontend's Wails runtime and its phone layout

## Building

    ./build_ffmpeg.sh                 # once: static FFmpeg for arm64
    ./build_runner.sh plain           # libmain.so (or gen -> train on a phone -> use, for PGO)
    ./make_apk.sh debug               # or: source <keys>/release.env; ./make_apk.sh release

`build_runner.sh` builds `BT3MOD` (default `~/NBAStreetRecomp/bt3mod-android`: the Mac native tree plus the Android
patch). Outputs go to `ANDROID_WORK` (default `~/NBAStreetRecomp/android`). Needs the NDK 28, Gradle's JDK 21 and Go.

PGO: `build_runner.sh gen`, install that build, run the game with `PS2X_PGO_WRITE_AT=150` (an autostart fight in the
60 fps mode: `PS2X_AUTOSTART=1 PS2X_NO_GAMEPAD=1 PS2X_FPS60=1`), `adb pull` the `pgo-*.profraw` from the app's external
files dir into `$ANDROID_WORK/pgo/`, then `build_runner.sh use`.

Debug builds start the game directly too (`adb shell am start -n io.github.recompcode.dbzbt4/.GameActivity`), with
`env.txt` (KEY=VALUE lines) and the disc files in `/sdcard/Android/data/io.github.recompcode.dbzbt4/files`.

## Measured (POCO F8 Ultra, Snapdragon 8 Elite Gen 5, 2608x1200, "Alta": 2x render + FSR 2 to 2187x1006)

60 fps fight: game 59-60 fps, window 60, p95 17.7 ms, 6.8 ms of guest CPU per frame. Without the game category the
system kept the cores at ~1 GHz (25 ms per frame); without ADPF the same; without the AHardwareBuffer path the CPU
copy of the frame took the window down to ~30 fps at that resolution.
