#!/bin/sh
# DBZ Budokai Tenkaichi 4 (mod de BT3) nativo en Mac: el juego recompilado + el GS de PCSX2 (pcsx2-gsrunner).
# Teclado: flechas = cruceta, WASD = stick izquierdo, Z/X/C/V = Cuadrado/Equis/Circulo/Triangulo,
# Q/E = L1/R1, 1/3 = L2/R2, Enter = START, Delete = SELECT. Menu grafico: F1. Cmd+Q cierra.
ROOT="$HOME/NBAStreetRecomp"
export PS2X_GS_LIVE=1
export PS2X_NET=0
export PS2X_LIVE_SERIAL=SLUS-21978
export PS2X_CD_IMAGE="${DBZ_ISO:-$HOME/Downloads/PS2_NTSC/SLUS_219.78.DBZBT4B14REV2.iso}"
export PS2X_GSHOST="$ROOT/gshost-dbz/pcsx2-gsrunner"
export PS2X_GSHOST_ARGS="${PS2X_GSHOST_ARGS:--ini $ROOT/gshost-dbz/dbz.ini}"
mkdir -p "$ROOT/dbz/logs" "$ROOT/dbz/iso/mc0"
cd "$ROOT/dbz/iso" || exit 1
exec "$ROOT/PS2Recomp-dbz/out/build-mac/ps2xRuntime/ps2EntryRunner" "$ROOT/dbz/iso/SLUS_219.78" \
    > "$ROOT/dbz/logs/native_play.log" 2> "$ROOT/dbz/logs/native_play_err.log"
