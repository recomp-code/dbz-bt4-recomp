@echo off
rem Igual que Jugar_DBZ.cmd pero con el preset DLSS: 2x interno reescalado por NVIDIA DLSS (gshost\dbz_dlss.ini).
rem   Jugar_DBZ_DLSS.cmd       30 fps
rem   Jugar_DBZ_DLSS.cmd 60    peleas a 60 fps
set DBZ_INI=dbz_dlss.ini
call "%~dp0Jugar_DBZ.cmd" %*
