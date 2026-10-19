#!/bin/bash
# Cierra el juego (cualquiera de las dos rutas) y la ventana del GS de PCSX2 que abrio.
pkill -f "bt3mod/build-(vk|live)/ps2xRuntime/ps2EntryRunner|games/bt3/work/SLUS_216.78" && echo cerrado
pkill -f "gshost-dbz/pcsx2-gsrunner -live" && echo "ventana de PCSX2 cerrada"
exit 0
