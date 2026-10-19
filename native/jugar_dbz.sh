#!/bin/bash
# Dragon Ball Z Budokai Tenkaichi 4 (mod BT4) nativo en Mac: BT3-Recomp adaptado al mod.
#
# Por defecto dibuja el GS de PCSX2 (pcsx2-gsrunner, Metal, escalado por hardware, como en PCSX2):
# la ventana del juego es la de PCSX2 y es la que recibe teclado y mando. Opciones graficas: tecla F1
# (o Back+Start / mantener START en el mando) dentro de esa ventana; se guardan en gshost-dbz/dbz.ini.
#
#   DBZ_RENDERER=pgs   la ruta anterior: paraLLEl-GS sobre MoltenVK (DBZ_SSAA=1/2/4, por defecto 2)
#   DBZ_WINDOW=1       ventana en lugar de pantalla completa (Alt+Enter o F11 cambia en cualquier momento)
#   DBZ_ISO=<ruta>     otra imagen del disco
#
# Controles en la ventana de PCSX2:
#   Teclado: flechas = cruceta, WASD = stick izquierdo, Z = cuadrado, X = cruz, C = circulo, V = triangulo,
#            Q / E = L1 / R1, 1 / 3 = L2 / R2, Enter = START, Mayus derecha o Retroceso = SELECT, Ctrl = L3.
#   Mando (el que tenga macOS, con la ventana en primer plano): botones y sticks como en PS2.
#   F1 = opciones graficas, Alt+Enter / F11 = pantalla completa, cerrar la ventana (Cmd+Q) = salir del juego.
# Cerrar: Cmd+Q en la ventana o ./parar_dbz.sh
export PS2X_CD_IMAGE="${DBZ_ISO:-$HOME/Downloads/PS2_NTSC/SLUS_219.78.DBZBT4B14REV2.iso}"
mkdir -p ~/NBAStreetRecomp/dbz/logs
ELF=~/NBAStreetRecomp/bt3mod/games/bt3/work/SLUS_216.78

if [ "${DBZ_RENDERER:-pcsx2}" = "pgs" ]; then
  cd ~/NBAStreetRecomp/bt3mod/build-vk/ps2xRuntime || exit 1
  export PS2X_PGS_SSAA="${DBZ_SSAA:-2}"
  export GRANITE_VULKAN_LIBRARY=/opt/homebrew/lib/libvulkan.1.dylib
  export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib:/usr/local/lib:/usr/lib
  exec ./ps2EntryRunner "$ELF" > ~/NBAStreetRecomp/dbz/logs/jugar.log 2>&1
fi

cd ~/NBAStreetRecomp/bt3mod/build-live/ps2xRuntime || exit 1
export PS2X_GS_LIVE=1
export PS2X_GSHOST=~/NBAStreetRecomp/gshost-dbz/pcsx2-gsrunner
HOSTARGS="-ini $HOME/NBAStreetRecomp/gshost-dbz/dbz.ini"
[ "${DBZ_WINDOW:-0}" = "1" ] || HOSTARGS="$HOSTARGS -fullscreen"
export PS2X_GSHOST_ARGS="$HOSTARGS"
export PS2X_LIVE_SERIAL=SLUS-21978
export PS2X_HOST_WINDOW="${PS2X_HOST_WINDOW:-1280x720}"
export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib:/usr/local/lib:/usr/lib
exec ./ps2EntryRunner "$ELF" > ~/NBAStreetRecomp/dbz/logs/jugar.log 2>&1
