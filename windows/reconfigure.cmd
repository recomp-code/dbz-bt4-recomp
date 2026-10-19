@echo off
rem Reconfigura el build del runner de DBZ BT4 (Ninja + clang-cl, sin consola, recursos con llvm-rc).
set PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set T=C:\NBAStreetRecomp\tools
set PATH=C:\DBZBT4Recomp\tools\pynuget\tools;%T%\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin;%T%\ninja;%T%\cmake\cmake-4.4.4-windows-x86_64\bin;%T%\mingit\cmd;%PATH%
rem Mismos flags que setup.py (Ninja + clang-cl); sin ellos CMake elige clang.exe (estilo GNU) y libarchive no compila.
cmake -S C:\DBZBT4Recomp\bt3mod -B C:\DBZBT4Recomp\bt3mod\build -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_RC_COMPILER=llvm-rc -DPS2X_SHOW_WINDOWS_CONSOLE=OFF
