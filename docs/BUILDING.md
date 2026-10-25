# Building DBZ BT4 Recomp from source

Technical notes moved out of the README: the build routes for Windows and macOS, what each patch does, and the
repository layout. To just play, use the ready-made zips (see the [README](../README.md)).

## The ready-made zips in detail

### Windows

**Your own DLSS:** drop a newer `nvngx_dlss.dll` into the `DLSS` folder (or onto the launcher window) and the game
uses it from the next start; with several, the newest version wins, and removing it goes back to the bundled one
(310.9.1). Files are recognised by their version info, so the name does not matter, and ARM builds are ignored. For
DLSS 5 without DLSS 5 Swapper, the same folder takes `nvngx_dlssnr.dll`, `ReShade64.dll` and `renodx-dlss5.addon64`.
The launcher shows which version is in use.

Needs Windows 10/11 64-bit and a GPU with Vulkan (DLSS on NVIDIA RTX, FSR on the rest). Xbox-style controllers and the
keyboard work out of the box. **Hold START for 1.5 s** (or F1) for the options menu: internal resolution,
DLSS / FSR, sharpness, anisotropic filtering, aspect ratio, fullscreen, FPS counter and **60 fps fights** (switched at
once, mid-fight too; the launcher's checkbox sets the starting value). `DBZ_BT4.exe --jugar` starts straight away with the saved
options (for a desktop shortcut). The zip has the recompiled runner and PCSX2's GS host, **not the disc**: the launcher
copies the ELF and the IRX modules out of your ISO into `runtime\data\` and the game streams everything else from the ISO.
Built with `windows/make_dist.ps1`; the launcher (Go + Wails, WebView2) is
[recomp-code/recomp-online](https://github.com/recomp-code/recomp-online) `launcher/`.

### Mac

Same game and same in-game menu as on Windows (F1 or hold START: internal resolution, MetalFX, 60 fps fights, FPS
counter...), drawn by PCSX2's GS on Metal. Controllers that macOS supports (Xbox, PlayStation, MFi) and the keyboard
work. Saves, options and logs live in `~/Library/Application Support/DBZ_BT4` (the app itself stays read-only).
`open -a DBZ_BT4 --args --jugar` starts straight away with the saved options. The app holds the recompiled runner,
PCSX2's GS host and its libraries, **not the disc**: the launcher copies the ELF and the IRX modules out of your ISO and
the game streams everything else from it. Built with `macos/make_dist.sh` (see [the `macos/` folder](#layout)); the
launcher is the same Recomp launcher as on Windows ([recomp-code/recomp-online](https://github.com/recomp-code/recomp-online)
`launcher/`, Go + Wails on WebKit), with the same [online play](../README.md#play-online): the session is kept encrypted with a key
in your Keychain, **Shift+Tab** or **Back + Start** brings the launcher over the game, and the controller does not move
your fighter while another window is in front. A Mac and a Windows copy with the same 60 fps table are paired (the
compatibility key, `net2-…` in AJUSTES, is the same on both).

### Online

Both players need the same release (the launcher says so otherwise). The match is lockstep: both games run the same
frames with both players' inputs, a few frames late (the input delay, measured automatically when the two meet) so they
have time to cross the internet through the relay; the two sides compare a hash of the game state as they go. If the
fight stutters because you are far apart, raise **Retraso de controles** in AJUSTES (the inviter's value is used).

## Status (2026-10-18)

- Boots through the Spike logo, intro FMV, title, memory card and menus, then character and stage select into fights.
- Browser: fights run at 60 fps with characters, HUD, specials and ki effects.
- Still to do:
  - **audio** is wrong: periodic stale chunks, mono output and extra content. The cause is localized in the EE-side CRI ring writes, probably another mistranslated instruction.
  - Some graphics glitches remain: white areas on some stages, block rectangles and flashes.
- Native macOS: work in progress.
- The "still to do" items above are the **browser** build's (our own PS2Recomp runtime + Play!'s GS). The native builds
  use BT3-Recomp's runtime, which does not have them.
- Native Windows (2026-10-19): playable end to end (Team BT4 splash, title, Dragon History, Duel with the whole unlocked
  roster, fights at 30 and 60 fps), with the fight-start fade drawn correctly (read-back answered by PCSX2) and DLSS/FSR.
  Audio: real stereo (a 264 s recording of menus and a fight: side/mid RMS 0.41, 3 mono seconds; `windows/wav_stats.py`).
  Graphics: no white areas or block rectangles seen on the stages visited so far (Wasteland, Tournament of Power); the
  remaining stages have not been checked one by one. BT3-Recomp's lockstep netplay (`PS2X_NET_LISTEN` / `PS2X_NET`)
  connects and stays in sync (0 desyncs over ~6400 frames between two instances on one PC); not tested between two PCs.

## Native Windows

The macOS route (BT3-Recomp + `patches/bt3recomp-bt4mod-full.patch` + PCSX2's GS in its own window) built with
clang-cl + Ninja, plus `patches/bt3recomp-bt4mod-windows.patch` (runtime) and `patches/pcsx2-gsrunner-dbz-windows.patch`
(host). The files in `windows/` assume the work folder `C:\DBZBT4Recomp` and the NBA Street V3 port's portable tools and
PCSX2 deps in `C:\NBAStreetRecomp` (LLVM 20, Ninja, CMake, MinGit; VS 2022 Build Tools for the SDK).

```bat
:: runtime
git clone https://github.com/z3xox/BT3-Recomp C:\DBZBT4Recomp\bt3mod && cd /d C:\DBZBT4Recomp\bt3mod && git checkout e22a34b
git apply --exclude=ps2xRuntime/third_party/parallel-gs ..\dbz-bt4-recomp\patches\bt3recomp-bt4mod-full.patch
git apply ..\dbz-bt4-recomp\patches\bt3recomp-bt4mod-windows.patch
:: the shared layers on top, in order (macos is a no-op on Windows, but perf applies on top of it)
for %p in (macos perf unlock netstats movieend livebatch perf2 seamperf glshare upscale fsr2 netnative descfix parity pacing metalfx maskpc mvfix rthread mfxsign jitsign retina vkpresent) do git apply ..\dbz-bt4-recomp\patches\bt3recomp-bt4mod-%p.patch
:: the native renderer (seamvk) builds when Granite has volk, khronos/vulkan-headers and fsr2 (FSR2's CPU side):
::   cd ps2xRuntime\third_party\parallel-gs\Granite && git submodule update --init --depth 1 -- third_party/volk third_party/khronos/vulkan-headers third_party/fsr2
python ..\dbz-bt4-recomp\windows\iso_extract.py <iso> extract games\bt3\work   &:: 7-Zip fails on the three big AFS files
set PS2X_SETUP_FORCE=1& set PS2X_SETUP_NO_SUBMODULES=1
python games\bt3\setup.py games\bt3\work\SLUS_219.78 --stages 3-3 --jobs 20 --no-deps --non-interactive --no-package
..\dbz-bt4-recomp\windows\reconfigure.cmd & ..\dbz-bt4-recomp\windows\build_runner.cmd   &:: GUI subsystem, llvm-rc
:: host: a copy of the NBA port's PCSX2 tree + patches\pcsx2-gsrunner-live-dbz.patch + patches\pcsx2-gsrunner-dbz-windows.patch
..\dbz-bt4-recomp\windows\build_pcsx2.cmd
:: then gshost\ = pcsx2-gsrunner.exe + the NBA gshost DLLs and resources\ (Team BT4's GameIndex.yaml) + nvngx_dlss.dll,
::               windows\gshost\dbz.ini and dbz_dlss.ini, and an empty portable.ini
```

Play with `windows\Jugar_DBZ.cmd` (30 fps), `Jugar_DBZ.cmd 60` / `Jugar_DBZ_60fps.cmd` (60 fps fights) or
`Jugar_DBZ_DLSS.cmd` (2x + DLSS); `set DBZ_WINDOW=1` for a window. F1 in the game window opens the GS options
(internal resolution, DLSS / FSR 1, sharpness, 60 fps fights; also Back+Start or holding START 1.5 s on a controller).
The menu saves it as `DbzFps60` in its ini and the launcher takes it as the next start's default. The 60 fps switch goes through the live ring: the host writes `fps60Request` and the game, at its next VSync, calls
BT3-Recomp's `ps2Set60Fps` and publishes its mode in `gameFps60` (two words in the padding of the header's third cache
line, so the layout and older builds are unaffected; `windows/fps60_ring_test.ps1` drives it without the menu).
paraLLEl-GS is off on Windows (`PS2X_DISABLE_PGS=ON` by default), so the
Granite submodules are not needed.

What the Windows patches change:
- **Live ring on Windows** (`ps2_gs_live.cpp`, `ps2_live_ring.h`): the upstream ring was POSIX only (`shm_open`,
  `posix_spawn`). On Windows it is a named mapping plus named auto-reset events (`Local\PS2RecompGsLiveRing_<pid>`, `...Data`,
  `...Space` and, for version 2, `...Readback`), the protocol of the NBA Street V3 port; the host is started with
  `CreateProcessW` + `CREATE_NO_WINDOW`. Version 2 on Windows: the readback block (`RingReadback` seq/bytes + 8 MB) follows
  the data area directly, since the POSIX "events" words do not exist in the mapping. Version 1 rings are still accepted.
  `PS2X_GSLIVE_READBACK=0` restores the old behaviour.
- **Host** (`GSDumpReplayer.cpp`): ReadFIFO2 replies on Windows too (upstream had them under `#if !defined(_WIN32)`).
- **PSMCT24 transfers are 3 bytes per pixel** (`Support.h` `bytesForPixels`; it said "treat as 32"). The fight-start fade
  downloads a 512x224 PSMCT24 frame into a 344064-byte buffer; counted as 4 bytes per pixel, `sceGsExecStoreImage` wrote
  458752 bytes. Once the GS host answers the download with real pixels, the overrun lands on the next heap block's header and
  the game's pool walk (`FUN_00254fe0`, pc 0x255018) loops forever at the start of every fight. This one affects every
  platform; it only went unnoticed while the overrun was filled with zeros from the runtime's own VRAM.
- `PS2X_PAD_SCRIPT="12:START,15.5:LEFT,16:CROSS+SQUARE"` (+ `PS2X_PAD_SCRIPT_HOLD` ms): timed presses for unattended tests,
  seconds since process start, or since the game first reaches a state with `PS2X_PAD_SCRIPT_STATE=0x4` (main menu);
  `PS2X_AUTOSTART_LEFT=1` makes the auto-start also answer "Si" to the memory-card prompts (`windows\run_test.ps1`,
  contact sheets with `windows\sheet.ps1`, the video script `windows\video_script.ps1`).
- `[avsync]` lines (with `PS2X_WAVCAP`): the WAV position every 60 live GS frames, so the host's `PS2X_CAPTURE` video and
  the runtime's audio can be muxed in sync (`windows\mux_video.ps1`, which retimes the audio piecewise where the game ran
  below 60 fps, e.g. during loads).

DLSS: the host from [street-recomp-v3](https://github.com/recomp-code/street-recomp-v3) (`4ca3ed7`): temporal DLSS with motion
vectors estimated on the GPU from the frames (luma block matching at 1/4 and 1/2 resolution, sub-texel refinement) and a
bias-current-colour mask where no good match exists, in Vulkan and D3D12; `PS2X_DLSS_MOTION=0`, `PS2X_DLSS_BIAS`,
`PS2X_DLSS_PRESET`. Measured on an RTX 4090: 6x native fights 2-5 ms of GPU per frame at 30 and 60 fps; the DLSS preset
(2x, 1024x896 -> 2400x1350) 4-10 ms. `nvngx_dlss.dll` 310.9.1 next to the host (DLSS Swapper can replace it).

### "DLSS 5" (DLSS Neural Rendering, experimental)

On an NVIDIA RTX card the DLSS output can go through NVIDIA's neural rendering pass with ReShade and the RenoDX
"DLSS 5" add-on (third-party, not included here), exactly as in the NBA Street V3 port: Direct3D 12, 2x internal + DLSS,
then the neural pass. In the zip it is the launcher's "DLSS 5" quality: when DLSS 5 Swapper is installed, the
launcher builds `gshost_dlss5\` itself from `gshost\` plus Swapper's ReShade (`ReShade64.dll` as `dxgi.dll`), the RenoDX
add-on and `nvngx_dlssnr.dll` (none of them ship in the zip), with `presets\ReShade.ini` and `presets\dbz_dlss_dx12.ini`.
From the development tree, `windows\Jugar_DBZ_DLSS5.cmd` (`... 60` for 60 fps fights) runs the game with a test copy of the
host, `gshost_hooktest\` = `gshost\` + ReShade's `dxgi.dll`, `renodx-dlss5.addon64`, its `ReShade.ini`,
`nvngx_dlssnr.dll` (e.g. from DLSS 5 Swapper) and `dbz_dlss_dx12.ini` (`dbz_dlss.ini` with `Renderer = 15`). In game: F6
toggles the pass, Home opens ReShade. DLSS, and so the pass, only runs while the window is larger than the 2x image
(1024x896): the launcher opens a 1920x1080 window or fullscreen. Measured on an RTX 4090: the pass evaluates on every
presented frame (`nr[evals]` = presents in `ReShade.log`), 59 fps in menus and 30 / 60 in fights.

## Native macOS with BT3-Recomp (playable)

The mod ELF has the same layout as BT3 USA (SLUS-216.78): 98.5% of BT3-Recomp's function starts match. The mod adds about 6 KB of code at the end of `BIN/DBZP.BIN` and patches roughly 70 jumps into the game.

```sh
git clone https://github.com/z3xox/BT3-Recomp bt3mod && cd bt3mod && git checkout e22a34b && git submodule update --init --recursive
git apply ../dbz-bt4-recomp/patches/bt3recomp-bt4mod.patch
(cd ps2xRuntime/third_party/parallel-gs && git apply ../../../../dbz-bt4-recomp/patches/parallel-gs-moltenvk.patch)
(cd ps2xRuntime/third_party/parallel-gs/Granite && git apply ../../../../../dbz-bt4-recomp/patches/granite-moltenvk.patch)
brew install cmake ninja pkg-config ffmpeg molten-vk vulkan-loader vulkan-headers
mkdir -p games/bt3/work && (cd games/bt3/work && tar -xf /path/to/SLUS_219.78.DBZBT4B14REV2.iso)
cp games/bt3/work/SLUS_219.78 /tmp/SLUS_219.78.elf
PS2X_SETUP_FORCE=1 python3 games/bt3/setup.py /tmp/SLUS_219.78.elf --jobs 6 --stages 3-3
cmake -S . -B build-vk -G Ninja -DCMAKE_BUILD_TYPE=Release -DPS2X_DISABLE_PGS=OFF && cmake --build build-vk --target ps2EntryRunner
mkdir -p build-vk/ps2xRuntime/savedata && cp ../dbz-bt4-recomp/native/settings.toml build-vk/ps2xRuntime/savedata/
../dbz-bt4-recomp/native/jugar_dbz.sh
```

What the patch does:
- **Mod detection and setup:** `setup.py` recognizes the mod by the word at 0x1133f4. It moves the heap start to 0x3C1200, because the mod's overlay runs up to 0x3C01D4. It also adds about 470 function rows and about 1,900 entry points generated by `games/bt3/bt4mod/bt4mod_maps.py`.
- **Recompiler:** a new `entry_points` config option, and functions that fall off their end now continue at the next address.
- **Runtime:** `bt4mod_overrides.cpp` holds the mod-specific code. The built-in 16:9 projection constant is kept, since the mod already has it.
- **Apple Silicon fixes:** sse2neon guards; ucontext `fpregs`, `link.h` and `dl_iterate_phdr` guarded to Linux; ImGui 1.93 tab color names; no-op seam markers when the native Vulkan seam renderer is off.
- **MoltenVK:** `PS2X_PGS_SSAA` overrides the render-scale-derived supersampling. 4x/8x drop fights to about 20 fps on an M2 Pro; 2x holds 30 fps.

### PCSX2 GS renderer (default)

`patches/bt3recomp-bt4mod-pcsx2gs.patch` (on top of the mod patch) adds a live GS stream to the runtime: with `PS2X_GS_LIVE=1`, every GIF packet (PATH1/2/3, exactly as the game sent it, before any of BT3-Recomp's renderer rewrites), the registers the libgs stubs write directly, local-to-host reads, and one register snapshot + VSync per published frame go over a shared-memory ring to `pcsx2-gsrunner -live` (the host from the NBA Street V3 port, `patches/pcsx2-gsrunner-live-dbz.patch`). The runtime's own GS parse runs state-only (`PS2X_GS_NODRAW`), paraLLEl-GS is off, and its window stays hidden. Keyboard and gamepad come from the PCSX2 window.

```sh
cmake -S . -B build-live -G Ninja -DCMAKE_BUILD_TYPE=Release -DPS2X_DISABLE_PGS=OFF && cmake --build build-live --target ps2EntryRunner
mkdir -p build-live/ps2xRuntime/savedata && cp ../dbz-bt4-recomp/native/settings-live.toml build-live/ps2xRuntime/savedata/settings.toml
# PCSX2 (the NBA port's tree) + patches/pcsx2-gsrunner-live-dbz.patch: cmake --build build-mac --target pcsx2-gsrunner,
# then copy pcsx2-gsrunner, its resources/ (with Team BT4's GameIndex.yaml) and gshost/dbz.ini into ~/NBAStreetRecomp/gshost-dbz
../dbz-bt4-recomp/native/jugar_dbz.sh            # DBZ_WINDOW=1 windowed, DBZ_RENDERER=pgs for paraLLEl-GS
```

`gshost/dbz.ini`: 6x internal resolution, bilinear (PS2) filtering, 16x anisotropic, no FXAA/CAS, merge post-processing sprites, CPU CLUT render (the GameIndex fix for SLUS-21978) and texture offsets picked per internal resolution (`UserHacks_TCOffsetByScale`: 2x 345, 3x-5x 425, 6x 500), also when the scale is changed from F1. The values were measured on this PCSX2 build by replaying one recorded fight frame at every scale and offset and comparing each, downscaled, with the 1x render (which has no doubled outline); Team BT4's 4K values (425/410) leave a doubled cel outline at 6x. On an M2 Pro, fights run at 30 fps with the GPU at 21-25 ms per frame, fullscreen at 3456x1944. F1 in the PCSX2 window opens its options menu. "Reescalado a la ventana" = Apple MetalFX (spatial scaler, ~0.3 ms) enlarges the frame to the window when the internal resolution is smaller (e.g. 3x at 60 fps); it sharpens edges but adds faint halos on the cel outlines, so 6x without it stays the cleanest. Changes are saved back to `dbz.ini`, and keys the menu does not show are kept.

Test helpers (`native/`): `lrun.sh` (run live), `lshot.sh` (the host saves its own frame), `lqshot.sh` (story-fight shots + fps), `ldump.sh`/`lreplay.sh`/`lcrop.py` (record the live stream as a `.gs` dump, then replay one identical frame with several `.ini` variants to compare settings).

## Layout

| Path | What |
| --- | --- |
| `config/config.toml`, `functions.csv`, `gap_*.txt` | Recompiler config and function map for the ELF + `BIN/DBZP.BIN` overlay (loaded at 0x334C00). `@ROOT@` is the work folder (`~/NBAStreetRecomp`). |
| `overrides/dbz_bt3_overrides.cpp` | Game-specific runtime code: libpad2, `sceCdSearchFile`, heap fixes, diagnostics. |
| `patches/ps2recomp-dbz.patch` | Engine changes on top of street-recomp-v3's patched PS2Recomp. These are generic fixes to be upstreamed there: VU0 macro LQI/SQI/LQD/SQD and VR* random-number ops, `ChangeThreadPriority`, IOP heap/sysmem alignment, SIF, and web options. |
| `patches/play-dbz.patch` | Play! GS (WebGL2) changes: exact framebuffers sampled on the GPU, a depth-mask pass, and write-back skipping. |
| `patches/pcsx2-live-serial.patch` | `pcsx2-gsrunner` live mode takes the game serial from `PS2X_LIVE_SERIAL`, so PCSX2's per-game GS fixes apply (superseded by `pcsx2-gsrunner-live-dbz.patch`, which includes it). |
| `patches/pcsx2-gsrunner-live-dbz.patch` | The serial change, plus: window title from `PS2X_LIVE_TITLE`, on-demand host screenshots (`PS2X_SHOT_DIR/host.req`), the options menu keeps unmanaged `.ini` keys, game flips counted as PCSX2 internal FPS, GPU time in the `PS2X_FPS_LOG` line, `PS2X_DUMP_FRAMES` for `-dumpdir`. |
| `patches/bt3recomp-bt4mod-pcsx2gs.patch` | BT3-Recomp runtime: the live GS stream to `pcsx2-gsrunner` (`PS2X_GS_LIVE=1`), `.gs` dumps (`PS2X_GS_DUMP`). |
| `patches/bt3recomp-bt4mod-widescreen.patch` | BT3-Recomp runtime (applied last): the mod already has the community 16:9 values built in, so the runtime's widescreen scaling is skipped. Scaling them again narrowed the sky backdrop (uncovered strips at the sides) and zoomed the camera in. |
| `patches/bt3recomp-bt4mod-fps60env.patch` | BT3-Recomp runtime: `PS2X_FPS60` (set by `native/jugar_dbz_60fps.sh`) wins over the saved 60 fps toggle, so the launcher can turn on BT3-Recomp's 60 fps fight mode (half-step table `games/bt3/fps60_sites.txt`; the mod keeps the USA layout). Story fight, M2 Pro, 3456x1944: 60 fps at 3x (GPU ~7 ms), 4x and 6x (GPU 12-16 ms, tight). |
| `patches/bt3recomp-bt4mod-full.patch` | The whole current BT3-Recomp tree change on upstream `e22a34b` (`git apply` it alone; it contains every layered patch above plus the browser work). Adds GS -> EE downloads through the live ring: the game's frame read-backs (fight-start fade) are answered by PCSX2 (ring version 2, readback area after the events; version 1 rings are still accepted), and `sceGsExecLoadImage`/`StoreImage` take `vram_addr` as a block address (the old `* 2048 / 256` wrapped, so the fade drew texture data as garbage blocks for ~0.4 s). |
| `patches/bt3recomp-bt4mod-windows.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-full.patch`: the Windows live ring (version 2 with readback), PSMCT24 transfer size, `PS2X_PAD_SCRIPT`. See [Native Windows](#native-windows). |
| `patches/pcsx2-gsrunner-dbz-windows.patch` | `pcsx2-gsrunner`, on top of the NBA port's tree + `pcsx2-gsrunner-live-dbz.patch`: ReadFIFO2 replies on Windows, the shared `Ps2LiveRing.h`. |
| `patches/bt3recomp-bt4mod-macos.patch` | BT3-Recomp runtime for the Mac app, on top of `bt3recomp-bt4mod-windows.patch`: `PS2X_GSHOST_ARGS` takes "quoted" arguments (the app's `-ini` path has spaces); in live mode the runner drops its Dock icon (only the game window shows one); online, the controller counts only while the game's window is the frontmost app; the fibers of online's virtual clock (`_XOPEN_SOURCE` before every header). |
| `patches/bt3recomp-bt4mod-perf.patch` | Performance, on top of the two above (shared code, macOS-only parts under `__APPLE__`): in live mode our GS parse keeps only what the game can observe (the GS thread ~34% -> ~12% of a core in a 60 fps fight); one per-thread block for the dispatcher's thread_locals; on macOS the vblank timer waits its last 2 ms with `mach_wait_until` at interactive QoS (timer coalescing made the frames 16-24 ms apart: ~10-15 repeated frames a second, now 0); `PS2X_PACEDIAG=1` frame pacing stats. Same state hashes as Windows. |
| `patches/bt3recomp-bt4mod-unlock.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-perf.patch`: `PS2X_UNLOCK_ALL=1` (the launcher's "Contenido desbloqueado", on by default and always on online) unlocks everything when the game first reaches the main menu, by running the game's own unlock routine `FUN_00266088` on the save data (what the main-menu cheat does: hold L1+R1, Down, Right, Triangle, Down, Left, Triangle, Up). Also fixes that cheat: its handler is the last instruction of `FUN_00299630` and the function bounds left out the jump's delay slot (`lw $a0, -0xd74($a0)`), so the recompiled cheat wrote its flags at 0x300000 instead of the save data (`apply_patches.py`, `[bt3 patch: cheatslot]`). |
| `patches/bt3recomp-bt4mod-netstats.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-unlock.patch`: `PS2X_NET_STATS_FILE=<path>` writes the result of every fight of an online match (`fight <n> winner=<1/2/0> c1= c2= hp1= hp2= frame=`) for the launcher's online statistics. The battle object (`*(u32 *)0x2feb48`) holds the phase at -0x50 (31 while fighting) and each side's life at +0x30/+0x34 (0..50000); the fighters' character ids are at `*(u32 *)0x2feb14 + 0xc64` and 0x1600 on. Only while the two games are connected; `PS2X_NET_STATS_OFFLINE=1` counts offline fights too (tests). |
| `patches/bt3recomp-bt4mod-movieend.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-netstats.patch`: the opening movie no longer stays black at its end when nobody presses a button. The game reads it with plain `sceCdRead` (no `sceCdSt*` stream end) and never asks `sceMpegIsEnd`: once the ~2802 pictures run out it calls `sceMpegGetPicture` forever. After 60 calls with no picture (counted in calls, so both games of an online match act at the same point), the MPEG stub pulses the skip button, as the native-movie override does. |
| `patches/bt3recomp-bt4mod-livebatch.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-movieend.patch`: cheaper live stream to the GS host. A transfer's header and data reach the host with one `writePos` store (it was one per field), and the host, when it is idle-waiting, is woken once 64 KB are unread (`PS2X_GSLIVE_WAKE_BYTES`, 0 = every packet as before) or at once for a VSync or a ReadFIFO2. In a 60 fps fight: ~40k host wake-ups a second down to ~18k, about 4 points of a core less in the runner and 3 in the host (Ryzen 5900X). The `[gslive]` stats line counts the wake-ups. Also: the live parse skips FLG=3 GIF tags as IMAGE, as the GIF does (it read their data as tags). Transport only otherwise: same state hashes online. |
| `patches/bt3recomp-bt4mod-perf2.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-livebatch.patch`: less overhead around the game code. The branch dispatcher (every guest call and return) reads its environment switches once at startup instead of ~25 thread-safe statics per branch, and its tick pump tests a mask instead of a 64-bit division; the hot-call cache has 4096 entries (512). The per-thread guest-lock depth is a fixed table instead of an `unordered_map` (one heap node per scheduler yield, two map copies per fiber switch), and the lock handoff wakes only when someone waits. The GIF arbiter reuses the buffers stage 2 hands back (each run regrew them from empty: ~20% of the kick worker). The 60 fps half-step tests a per-pc bit before its hash lookup. `PS2X_BENCH_UNCAP_AT=<s>` / `PS2X_BENCH_VBLANK_US`: run uncapped from that second, to measure throughput. No change to what the game sees: same state hashes online (8600 frames, one side on 2 cores). |
| `patches/bt3recomp-bt4mod-seamperf.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-perf2.patch`: the native Vulkan renderer (`PS2X_SEAMVK=1` or renderer "native"; the build needs paraLLEl-GS's Granite with its `volk` and `khronos/vulkan-headers` submodules) stops reallocating every frame. The frame list it takes from the GS front end is kept, so the front end refills vectors that already have their capacity (a fresh list each frame regrew ~550 draws and ~2.8 MB of vertices from empty and freed them again); the seam-mesh batch groups keep their index vectors; vertex data goes through a per-frame host ring instead of Granite's 4 KB-block pool (larger requests got a dedicated buffer destroyed a frame later); render-target decodes take images from the free pool too, and a full pool drops its oldest image instead of the one coming back. The ring slot is waited before recording, not after. Uncapped fight, Ryzen 9 5900X + RTX 4090, render scale 3: 91 -> ~118 fps (the PCSX2 host path: ~110); the GS thread now idles part of each frame. Same picture. |
| `patches/bt3recomp-bt4mod-glshare.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-seamperf.patch`: zero-copy present for the native renderer (new `ps2_seamvk_gl.cpp`). The composed frame is copied on the GPU into one of four exportable images (released to `VK_QUEUE_FAMILY_EXTERNAL`); the window's GL context imports their memory once (`GL_EXT_memory_object`, Win32 handles / fds) and waits a fresh exported semaphore per frame (`GL_EXT_semaphore`) before sampling; a slot goes back to the renderer when a GL fence after its last draw signals. Before, every frame (4.6 MB at 1280x896) was read back to the CPU, copied twice and uploaded to GL again. It turns itself off (CPU readback as before) without the extensions, when GL runs on another GPU than Vulkan (LUID / UUID check: hybrid laptops), on macOS, or with `PS2X_SEAMVK_GLSHARE=0`. 60 fps fight: 1.70 -> 1.07 cores; uncapped: ~118 -> ~128 fps (Ryzen 9 5900X + RTX 4090, render scale 3). |
| `patches/bt3recomp-bt4mod-upscale.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-glshare.patch`: DLSS for the native renderer with the game's **real** depth and **real** motion vectors (`PS2X_SEAMVK_UPSCALE=dlss`; the PCSX2 host had a stand-in depth and vectors estimated by block matching). Each seam mesh chunk is recognised from frame to frame by its model-space vertices, and its previous constants give where every vertex was; a motion pass redraws the shown frame's meshes into an RG16F image with the same position code as the draw (`seamvk/seam_xform.glsl`, `invariant gl_Position`) and depth EQUAL, then depth and motion are mapped into the composed frame's space (`upaux.frag`). The renderer composes at the full render size and DLSS upscales it to the window (1-3x per axis). The 3D meshes of the shown frame are jittered (Halton 2,3, 8 x scale^2 phases, through their viewport origin; the HUD stays put) once the upscaler runs; the sign was measured on 40 dumped frames (frame-to-frame change 1.91 vs 2.62 unjittered vs 2.79 with the wrong sign). NGX runs on a Vulkan device of its own on the same GPU (on Granite's descriptor-heap device its kernels output black): four exportable images and two exported semaphores per frame, no CPU wait. Built when the NGX SDK is found (`PS2X_DLSS_SDK`, Windows x64 / Linux x86_64; not macOS); `nvngx_dlss.dll` goes next to `ps2EntryRunner.exe`. Shaders are compiled with glslang (`glslangValidator -V --target-env vulkan1.1 -x`, include directive in the preamble). |
| `patches/bt3recomp-bt4mod-fsr2.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-upscale.patch`: AMD FidelityFX FSR2 for the native renderer on any GPU (`PS2X_SEAMVK_UPSCALE=fsr`, and the fallback of `dlss` where DLSS cannot run), fed the same real depth, motion vectors and jitter, on the renderer's own device and command buffer. The CPU side is Granite's FSR2 fork (`third_party/fsr2`); `src/lib/seamvk/ffx_fsr2_granite_baked.cpp` is its Granite backend with the compute passes pre-baked to SPIR-V with their binding layouts (`fsr2_baked.inc`, made by `windows/bake_fsr2.ps1` with glslang: LDR, render-resolution vectors, inverted depth, no FP16), so the runtime carries no shader compiler and no SPIR-V reflection. Jitter sign measured as for DLSS (FSR2 counts y upwards): frame-to-frame change 2.07 with "-+" against 2.9-3.0 for the other three. The motion pass's chunk tables are flat open-addressing arrays reused every frame (an `unordered_map` of 496-byte nodes was ~6% of the GS thread); 60 fps fight with DLSS: 1.09 cores. |
| `patches/bt3recomp-bt4mod-netnative.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-fsr2.patch`: online with the native renderer. The fight-start fade downloads a frame from the GS into EE RAM (`sceGsSyncStoreImage`); those pixels come from PCSX2's GPU with the live host and from the runtime's own VRAM under the native renderer, so they now leave the online state hash in every mode (before, only the host's answer did, and a native player and a PCSX2 player desynced from frame 3060). Measured: native vs native and native vs PCSX2, 0 desyncs in ~8100 frames each (60 fps, one side on 2 cores). |
| `patches/bt3recomp-bt4mod-descfix.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-netnative.patch`: the native renderer on every Vulkan descriptor model. Binding 2 of `gs.frag`, `alias16.frag`, `clutpass.frag` and `glowcomp.frag` is a `subpassInput`, but the programs' resource layouts declared it a sampled image; only Granite's descriptor-heap model (recent NVIDIA drivers) tolerated it, the descriptor-buffer and classic models wrote an empty image descriptor and the driver crashed in the first GS draw. Classic is the only model MoltenVK has (macOS), and older AMD / Intel drivers lack the heap. `PS2X_SEAMVK_DESCMODEL=legacy|buffer` forces a model (tests): both now run the whole fight. |
| `patches/bt3recomp-bt4mod-parity.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-descfix.patch`: the native renderer's defaults look like the PCSX2 host's picture. The widescreen HUD is edge-pinned (`video.hud.layout` 1: bars and portraits at the screen edges, as the host lays them out; 0 = centered 4:3 stays available), and the depth-of-field blur is on (`video.dof_blur`: the far field softened, graded by depth; the game's own byte mask leaves tilted bands at high resolution). Measured against the host on the same fight: same brightness (an apparent 9% gap was the intro's fade-in caught at different moments), glow on ki attacks as strong. Settings files already written keep their values. |
| `patches/bt3recomp-bt4mod-pacing.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-parity.patch`: `[pacing]` once a second in the native renderer's log: frames presented, frames more than 25 ms after the previous one and the worst gap (the PCSX2 host's "hitches>25ms"). 60 fps fight with DLSS, last 50 s: 2 cores / 4 threads 5 hitches (worst 34 ms; the host path had 90-105), all cores 0. Average fps is the same on 4 and 24 threads (57.9: the game's own 30 fps cinematics pull it under 60 in both renderers). |
| `patches/bt3recomp-bt4mod-metalfx.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-pacing.patch` (macOS only; nothing changes elsewhere): the native renderer on a Mac upscales with **Apple MetalFX** (temporal), not FSR2 (not built on macOS). Same inputs as DLSS / FSR2: the composed colour, the real inverted depth, the real motion (render pixels) and the jitter, whose sign is DLSS's ("--": mean frame-to-frame change of the 3D area 0.73, against 0.80 / 0.89 / 1.05 for the other three). MoltenVK hands over the Metal objects under the Vulkan images and queue (`VK_EXT_metal_objects`): the frame so far is submitted (MoltenVK commits it inside `vkQueueSubmit`, `MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS` pinned), the scaler is encoded on the same `MTLCommandQueue` behind it, and the rest of the frame follows in a new command buffer: no copy, no semaphore, no CPU wait (`ps2_seamvk_metalfx.mm`). Every `PS2X_SEAMVK_UPSCALE` value (`metalfx`, and the launcher's `dlss`) means MetalFX on a Mac; it runs when the window is 1-3x the render per axis (MetalFX's limit on an M2 Pro). Fullscreen on macOS is the desktop kind (its own Space at the display's resolution, `SDL_WINDOW_FULLSCREEN_DESKTOP`): the plain one switched the display's mode to the window's size, 1280x800 on a MacBook Pro, and MetalFX had nothing larger to reach. Also: pkg-config's static FFmpeg hands `-framework X` as two link options and CMake de-duplicates options token by token, so with any other framework on the link line CoreVideo / CoreMedia were left bare; each pair is kept whole. Measured on an M2 Pro (MoltenVK 1.4.2, classic descriptor model), window 1728x972, render 2x: fights at a steady 30 fps (~1.1 cores) and 60 fps with the 60 fps mode (0 hitches over 25 ms, worst frame 21 ms, ~1.5 cores). |
| `patches/bt3recomp-bt4mod-maskpc.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-metalfx.patch` (every system): the native depth-mask pass (`depthmask.frag`, step 0) takes 16 bytes of push constants (`dofOff`, always 1 since `[dofgraded]`), but its resource layout declared none, so the push was out of the pipeline layout's range. NVIDIA's driver delivered the value anyway; MoltenVK did not, so on a Mac the mask was never neutralised and wrote `Z24[15:8]`, which wraps every 65536 Z units on the receding ground; the haze / blur-weight step (`FUN_00245a50`, CLUT indexed by that byte through `0x1c00`) then drew thin light lines across the fight's floor wherever the DoF blur was on. Found by skipping the post steps one by one (only step 3 removed them) and drawing step 3's CLUT index as grey (a depth ramp wrapping exactly on the line). The layout now declares the range; Ztop and the 2:1 downscale share it and ignore it. Any other driver that honours the layout strictly (AMD, Intel) had the same lines. |
| `patches/bt3recomp-bt4mod-mvfix.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-maskpc.patch` (every system; feeds DLSS, FSR 2 and MetalFX): the native motion vectors, checked against the picture with `PS2X_SEAMVK_MVCHECK=1` (every 300th frame: the previous frame reprojected with +mv, none and -mv, bilinear, plus a per-axis scale sweep; `PS2X_SEAMVK_MVCHECKDIR` also writes both frames and the vectors as PPM). Four defects it found: (1) the motion pass tested depth EQUAL against the scene, which never matched bit for bit, so every vector was zero -- it now has a D32 depth of its own (GEQUAL + write); (2) the scene target was taken from DISPFB, but the game alternates its buffers, so every other frame had no motion and the upscaler dropped its history -- it is now the target most seam meshes drew to; (3) repeated meshes (trees, rocks, ground tiles) were paired with last frame's by draw order -- instances of one mesh are now chained and each takes the previous instance with the closest matrices; (4) the screen shake of heavy hits moves XYOFFSET and the display start, not the matrices -- both now enter the vector. Also `[mvreuse]`: the motion pass replays the main pass's own vertex and constant ranges (only the previous constants are new), and the GIF arbiter's in-place drain returns its buffers to the pool. With real motion the reprojection error drops to a fraction of the no-motion error (e.g. 1.10 vs 5.72, 1.55 vs 6.62). |
| `patches/bt3recomp-bt4mod-rthread.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-mvfix.patch` (every system): the native renderer records on a thread of its own. The GS thread parsed the game's packets and then recorded and submitted the Vulkan frame, and was the limit uncapped (~87% busy); at the swap it now only takes the frame list and queues it, and a render thread (Granite's thread index 0, the only one that records) renders it while the GS thread parses the next frame. Two lists in turn: at most one queued and one rendering. `PS2X_SEAMVK_RTHREAD=0` keeps one thread. Uncapped fight at 2x without an upscaler: 111 -> 122 fps (the guest thread is now the limit); with DLSS unchanged (~115, bound by the DLSS hand-over); 2c/4t at 60 fps unchanged. Also: the motion pass matches instances on their translation rows (8 floats, not 48: a field of identical grass tufts was quadratic) and writes the previous constants straight into the ring (`allocConsts`), 12% -> 7% of the GS thread. |
| `patches/bt3recomp-bt4mod-mfxsign.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-rthread.patch` (macOS only): MetalFX's jitter offset is `+x, -y` of the scene's shift (`PS2X_METALFX_JITTER_SIGN` overrides), not DLSS's `--`, which `metalfx` had taken while the motion vectors were still all zero. Measured once they were real: the sign switched every 16 frames inside one fight, so the four candidates see the same motion; over 32 blocks in two orders, frame-to-frame change of the 3D area relative to the block's mean: `+-` 0.85 (best in 13 blocks), `--` 0.92, `++` 0.99, `-+` 1.24 (separate runs could not tell them apart: the fight varies more from run to run than the effect). `mvfix` checked under MoltenVK: reprojection error 1.98 with the vectors, 2.45 without, 2.79 reversed; the scale sweep bottoms out at 1.00 on both axes, the scale MetalFX is given (Apple's header documents the same convention, `(-10,-10)` for a move of 10 px down-right). With `rthread`, a 60 fps fight with MetalFX on an M2 Pro: 0 hitches over 25 ms, worst frame 17.7 ms. |
| `patches/bt3recomp-bt4mod-jitsign.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-mfxsign.patch` (Windows / Linux: DLSS and FSR 2): the jitter sign pairs re-measured with the real motion vectors. `PS2X_UPSCALE_JITSIGN_CYCLE=1` (with `PS2X_SEAMVK_GLSHARE=0`) switches the pair every 16 frames inside one fight, in both orders, and the readback consumer reports the frame-to-frame change of the 3D area per pair relative to each 64-frame cycle's mean (fight frames only). DLSS, two runs of 48 cycles: `++` 0.894 / 0.856 (best in 26 / 25), `--` (the old default, picked while every vector was zero) 1.134 / 1.107, the worst. FSR 2, three runs: much less sensitive; `++` wins the most cycles (53 of 144) and matches DLSS (both take the offset in pixels). Both now default to `++`; `PS2X_DLSS_JITTER_SIGN` / `PS2X_FSR2_JITTER_SIGN` override. MetalFX keeps `mfxsign`'s `+-` (the cycle mode drives it too). |
| `patches/bt3recomp-bt4mod-retina.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-jitsign.patch` (macOS only; a no-op elsewhere): the native renderer's window uses the display's real pixels. The window is created high-DPI (`FLAG_WINDOW_HIGHDPI`, not with the PCSX2 host; `PS2X_RETINA=0` keeps the points-sized framebuffer), raylib's SDL2 `GetWindowScaleDPI` is implemented (GL drawable over window size), the GS render-target passes restore a pixel viewport with a points projection, and the present / upscaler target is the window in pixels: MetalFX writes 3456x2234 on a 14" MacBook Pro fullscreen instead of 1728x1117 stretched by macOS. Zero-copy present (`[macshare]`, the Mac counterpart of `glshare`): each frame a Metal blit on the renderer's queue copies the presented image into one of three IOSurfaces, which the window's GL context binds (`CGLTexImageIOSurface2D`) and copies into its texture on the GPU, with no CPU readback (31 MB per frame at Retina fullscreen) and no alpha pass (the texture swizzles A to 1). In the 60 fps mode MetalFX's output is capped at 3.8 Mpx and the window's bilinear present does the rest (M2 Pro fullscreen, 60 fps mode: uncapped 55.7 fps, MetalFX 4.2 ms; capped 59.5-60.0); 30 fps stays uncapped; `PS2X_METALFX_OUT=<0.5..1>` fixes the per-axis fraction. `PS2X_METALFX_TIMING=1` logs MetalFX's GPU time. |
| `patches/bt3recomp-bt4mod-vkpresent.patch` | BT3-Recomp runtime, on top of `bt3recomp-bt4mod-retina.patch` (Windows; opt-in, `PS2X_SEAMVK_VKPRESENT=1`): the window presented through a Vulkan swapchain on the native renderer's device instead of GL's SwapBuffers. GL still draws everything (the game frame, movies, overlays) into its back buffer; raylib's `SwapScreenBuffer` asks a hook first (`bt3SwapHook`, `rcore_desktop_sdl.c`), which blits the back buffer into a Vulkan image GL imports (`GL_EXT_memory_object_win32`), signals an exported semaphore, and Vulkan blits that into a swapchain image and presents it (submit and present under Granite's `external_queue_lock`). The swapchain lives on a disabled child window that returns `HTTRANSPARENT` (Vulkan cannot present to a window GL owns), so input still reaches SDL; it follows resizes. `PS2X_SEAMVK_VKPRESENT_MODE=fifo` (default) / `mailbox` / `immediate`. The device enables `VK_KHR_swapchain` and the instance `VK_KHR_surface` / `VK_KHR_win32_surface` only when asked. Same picture and speed as GL (uncapped 123 / 123-125 fps off / on); the base for frame generation. The display loop is still paced at 60 Hz by the runtime. |
| `patches/pcsx2-gsrunner-perf2.patch` | `pcsx2-gsrunner`, on top of `pcsx2-gsrunner-dbz-windows.patch` (shared code): the Vulkan allocator refetches the memory budget (a kernel query) every 8 command buffers instead of at each one (DBZ switches command buffers at every readback: 14% of the GS thread); `PS2X_HWDOWNLOAD_MODE=0..4` overrides the preset's `HWDownloadMode` (the launcher sets 2 offline: the glow's palette readback no longer stalls the GS thread, +12% frames in an uncapped fight, same picture; online keeps the accurate mode). Uncapped fight on a Ryzen 9 5900X, both layers: 89 -> ~110 fps. |
| `patches/pcsx2-gsrunner-macos-online.patch` | Mac GS host, on top of `pcsx2-gsrunner-live-dbz.patch`: Back + Start belongs to the launcher, so with Back held Start does not open the host's menu (F1 and holding START still do). Quit (Cmd+Q, Dock) stops the VM in order; `PS2X_HITCH_MS` sets the gap counted as a hitch (with `PS2X_FPS_LOG=1`); the live stream is read in blocks of whatever the game wrote (one ring publish per block, the host's ring reading ~4x cheaper), and the game's liveness is checked at most every 50 ms (`PS2X_LIVE_STAGE=0`: the old reads). `PS2X_HOST_NOACTIVATE=2` (tests on a Mac someone is using): the window is invisible, at the back, and lets clicks through. |
| `macos/` | The Mac package: `build_launcher.sh` (the Recomp launcher from a recomp-online checkout, `RECOMP_ONLINE`, with the server built in), `build_ffmpeg.sh` (minimal static FFmpeg), `build_runner.sh` (runner for macOS 14+ with only system libraries), `make_dist.sh` (`DBZ_BT4.app`: dylibs into Frameworks, presets, icon, ad-hoc signature, zip), `Info.plist`, `settings.toml`, `LEEME.txt`. |
| `windows/` | Windows launchers (`Jugar_DBZ*.cmd`), build scripts (`env.ps1`, `reconfigure.cmd`, `build_runner.cmd`, `build_pcsx2.cmd`, `make_patch.ps1`), `gshost/dbz.ini` (Vulkan, 6x) and `gshost/dbz_dlss.ini` (2x + DLSS), `iso_extract.py` (ISO9660 extractor), tests (`run_test.ps1`, `sheet.ps1`, `stack_snapshot.ps1`). |
| `docs/screenshots/`, `docs/videos/` | Screenshots and the showcase video of the native Windows build. |
| `gshost/dbz.ini` | PCSX2 GS settings, based on the Team BT4 1080p profile: 3x, merge PP sprites, TC offsets, 16:9. The `GameIndex.yaml` with the SLUS-21978 fixes comes from the Team BT4 PCSX2 extras. |
| `tools/` | Map and recompile helpers (`mkcombined.py`, `fixcsv.py`, `gaps.py`, `recomp.sh`, `build.sh`), `play_native.sh`, analysis tools (`adxdec.py`, `gstrace.py`, `mdis.py`, `xref.py`), headless tests (`tools/test`), and the local web server and diagnostics receiver (`tools/web`). |
