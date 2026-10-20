@echo off
rem Dragon Ball Z Budokai Tenkaichi 4 (mod BT4 Beta 14 Rev2) recompilado para Windows (BT3-Recomp + mod).
rem Dibuja el GS de PCSX2 (pcsx2-gsrunner, Vulkan, 6x interno, DLSS/FSR en F1): la ventana del juego es la de
rem PCSX2 y es la que recibe teclado y mando.
rem
rem   Jugar_DBZ.cmd            peleas a 30 fps (como la PS2)
rem   Jugar_DBZ.cmd 60         peleas a 60 fps (modo 60 fps de BT3-Recomp)
rem   set DBZ_WINDOW=1         en ventana (Alt+Enter o F11 cambia en cualquier momento)
rem   set DBZ_ISO=<ruta>       otra imagen del disco
rem
rem Controles en la ventana de PCSX2:
rem   Teclado: flechas = cruceta, WASD = stick izquierdo, Z/X/C/V = Cuadrado/Cruz/Circulo/Triangulo,
rem            Q/E = L1/R1, 1/3 = L2/R2, Enter = START, Retroceso = SELECT.
rem   Mando XInput (Xbox o compatible): A=Cruz, B=Circulo, X=Cuadrado, Y=Triangulo.
rem   F1 (o Back+Start / mantener START) = opciones graficas: resolucion interna, DLSS / FSR, nitidez...
rem   Se guardan en C:\DBZBT4Recomp\gshost\dbz.ini. Cerrar la ventana = salir del juego.
setlocal
set R=C:\DBZBT4Recomp
if "%DBZ_ISO%"=="" set DBZ_ISO=%USERPROFILE%\Documents\PS2_NTSC\SLUS_219.78.DBZBT4B14REV2.iso
set PS2X_CD_IMAGE=%DBZ_ISO%
set PS2X_GS_LIVE=1
if "%PS2X_GSHOST%"=="" set PS2X_GSHOST=%R%\gshost\pcsx2-gsrunner.exe
set PS2X_LIVE_SERIAL=SLUS-21978
set PS2X_LIVE_TITLE=Dragon Ball Z Budokai Tenkaichi 4
rem DBZ_INI: dbz.ini (6x nativo, por defecto) o dbz_dlss.ini (2x + DLSS), ambos en gshost\.
if "%DBZ_INI%"=="" set DBZ_INI=dbz.ini
set HOSTARGS=-renderer vulkan -ini %R%\gshost\%DBZ_INI%
if not "%DBZ_WINDOW%"=="1" set HOSTARGS=%HOSTARGS% -fullscreen
if "%PS2X_GSHOST_ARGS%"=="" set PS2X_GSHOST_ARGS=%HOSTARGS%
if "%1"=="60" (
  set PS2X_FPS60=1
  set PS2X_HALFSTEP=%R%\bt3mod\games\bt3\fps60_sites.txt
) else (
  set PS2X_FPS60=0
)
if "%PS2X_HOST_WINDOW%"=="" set PS2X_HOST_WINDOW=1280x720
if not exist "%R%\logs" mkdir "%R%\logs"
rem El runtime escribe su log con PS2X_LOGFILE (redirigir con "> archivo" puede colgarlo). Log del host: gshost\logs\emulog.txt
set PS2X_LOGFILE=%R%\logs\jugar.log
cd /d "%R%\bt3mod\build\ps2xRuntime"
start "" /wait "%R%\bt3mod\build\ps2xRuntime\ps2EntryRunner.exe" "%R%\bt3mod\games\bt3\work\SLUS_216.78"
