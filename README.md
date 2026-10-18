# DBZ Budokai Tenkaichi 4 (BT3 mod) — PS2Recomp

Static recompilation of *Dragon Ball Z: Budokai Tenkaichi 4* (the Team BT4 fan mod of BT3, disc `SLUS-219.78`,
"Beta 14 Rev2") with [PS2Recomp](https://github.com/ran-j/PS2Recomp). It runs on two targets:

- **Native macOS**: the recompiled game plus PCSX2's GS (`pcsx2-gsrunner`), the same layout as the native NBA Street V3 build.
- **Browser** (WebAssembly): the web runtime from [street-recomp-v3](https://github.com/recomp-code/street-recomp-v3) with Play!'s GS on WebGL2.

**This repository contains no game code or data.** Bring your own disc image. The game's code is generated
from your ELF at build time.

## Status (2026-10-18)

- Boots through the Spike logo, intro FMV, title, memory card and menus, then character and stage select into fights.
- Browser: fights run at 60 fps with characters, HUD, specials and ki effects.
- Still to do:
  - **audio** is wrong: periodic stale chunks, mono output and extra content. The cause is localized in the EE-side CRI ring writes, probably another mistranslated instruction.
  - Some graphics glitches remain: white areas on some stages, block rectangles and flashes.
- Native macOS: work in progress.

## Layout

| Path | What |
| --- | --- |
| `config/config.toml`, `functions.csv`, `gap_*.txt` | Recompiler config and function map for the ELF + `BIN/DBZP.BIN` overlay (loaded at 0x334C00). `@ROOT@` is the work folder (`~/NBAStreetRecomp`). |
| `overrides/dbz_bt3_overrides.cpp` | Game-specific runtime code: libpad2, `sceCdSearchFile`, heap fixes, diagnostics. |
| `patches/ps2recomp-dbz.patch` | Engine changes on top of street-recomp-v3's patched PS2Recomp. These are generic fixes to be upstreamed there: VU0 macro LQI/SQI/LQD/SQD and VR* random-number ops, `ChangeThreadPriority`, IOP heap/sysmem alignment, SIF, and web options. |
| `patches/play-dbz.patch` | Play! GS (WebGL2) changes: exact framebuffers sampled on the GPU, a depth-mask pass, and write-back skipping. |
| `patches/pcsx2-live-serial.patch` | `pcsx2-gsrunner` live mode takes the game serial from `PS2X_LIVE_SERIAL`, so PCSX2's per-game GS fixes apply. |
| `gshost/dbz.ini` | PCSX2 GS settings, based on the Team BT4 1080p profile: 3x, merge PP sprites, TC offsets, 16:9. The `GameIndex.yaml` with the SLUS-21978 fixes comes from the Team BT4 PCSX2 extras. |
| `tools/` | Map and recompile helpers (`mkcombined.py`, `fixcsv.py`, `gaps.py`, `recomp.sh`, `build.sh`), `play_native.sh`, analysis tools (`adxdec.py`, `gstrace.py`, `mdis.py`, `xref.py`), headless tests (`tools/test`), and the local web server and diagnostics receiver (`tools/web`). |

## Credits

- [PS2Recomp](https://github.com/ran-j/PS2Recomp), [Play!](https://github.com/jpd002/Play-), [PCSX2](https://github.com/PCSX2/pcsx2).
- [z3xox/BT3-Recomp](https://github.com/z3xox/BT3-Recomp) (GPL-3.0): the VU0 macro and VR* translation fixes in `patches/ps2recomp-dbz.patch` come from its `ps2xRecomp/src/lib/vu_translation_helpers.cpp`.
- Team BT4 for the mod and its PCSX2 settings.

License: GPL-3.0 (see `LICENSE`).
