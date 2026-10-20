@echo off
rem DBZ BT4 con "DLSS 5" (DLSS Neural Rendering via ReShade + el addon RenoDX DLSS5): Direct3D 12, 2x interno + DLSS
rem y el pase neural encima. Usa la copia de prueba del host en gshost_hooktest\ (tu gshost\ normal no se toca).
rem   Jugar_DBZ_DLSS5.cmd       peleas a 30 fps
rem   Jugar_DBZ_DLSS5.cmd 60    peleas a 60 fps
rem En el juego: F6 = pase neural si/no (para comparar), Inicio = menu de ReShade/addon, F1 = opciones del GS.
setlocal
set R=C:\DBZBT4Recomp
set PS2X_GSHOST=%R%\gshost_hooktest\pcsx2-gsrunner.exe
set PS2X_GSHOST_ARGS=-renderer dx12 -ini dbz_dlss_dx12.ini
if not "%DBZ_WINDOW%"=="1" set PS2X_GSHOST_ARGS=%PS2X_GSHOST_ARGS% -fullscreen
rem DLSS (and so the neural pass) only runs when the window is larger than the 2x internal image (1024x896)
if "%PS2X_HOST_WINDOW%"=="" set PS2X_HOST_WINDOW=1920x1080
call "%R%\Jugar_DBZ.cmd" %1
