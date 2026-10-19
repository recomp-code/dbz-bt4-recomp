@echo off
rem Recompila (incremental) ps2EntryRunner de DBZ BT4 con clang-cl + Ninja.
rem vcvars64 necesita vswhere.exe en el PATH; sin el, el entorno del SDK queda a medias y rc.exe se cuelga.
set PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set T=C:\NBAStreetRecomp\tools
set PATH=C:\DBZBT4Recomp\tools\pynuget\tools;%T%\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin;%T%\ninja;%T%\cmake\cmake-4.4.4-windows-x86_64\bin;%T%\mingit\cmd;%PATH%
cmake --build C:\DBZBT4Recomp\bt3mod\build --target ps2EntryRunner -j 20
