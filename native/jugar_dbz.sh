#!/bin/bash
# Dragon Ball Z Budokai Tenkaichi 4 (mod BT4) nativo en Mac: BT3-Recomp + paraLLEl-GS (Vulkan sobre Metal, MoltenVK).
# Pantalla completa, supermuestreo x2, 30 fps en peleas. Cambia DBZ_SSAA=1/2/4 (4 = mas nitido pero ~20 fps).
# Teclado: ver el menu del juego (overlay). Cerrar: Cmd+Q o ./parar_dbz.sh
cd ~/NBAStreetRecomp/bt3mod/build-vk/ps2xRuntime || exit 1
export PS2X_CD_IMAGE="${DBZ_ISO:-$HOME/Downloads/PS2_NTSC/SLUS_219.78.DBZBT4B14REV2.iso}"
export PS2X_PGS_SSAA="${DBZ_SSAA:-2}"
export GRANITE_VULKAN_LIBRARY=/opt/homebrew/lib/libvulkan.1.dylib
export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib:/usr/local/lib:/usr/lib
mkdir -p ~/NBAStreetRecomp/dbz/logs
exec ./ps2EntryRunner ~/NBAStreetRecomp/bt3mod/games/bt3/work/SLUS_216.78 > ~/NBAStreetRecomp/dbz/logs/jugar.log 2>&1
