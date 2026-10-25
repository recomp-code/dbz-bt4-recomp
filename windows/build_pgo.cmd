@echo off
rem [pgo] Runner nativo compilado con PGO (perfil de ejecucion de clang), en carpetas propias:
rem   build_pgo.cmd gen   -> build-pgo-gen: instrumentado (-fprofile-instr-generate); juega el combate de prueba con
rem                          LLVM_PROFILE_FILE=<bt3mod>\pgo\pgo-%%p.profraw y PS2X_PGO_WRITE_AT=<segundos> (escribe el perfil)
rem   build_pgo.cmd use   -> une pgo\*.profraw en pgo\runner.profdata y compila build-pgo con el. El perfil sale del codigo
rem                          generado desde tu ELF: se queda en tu disco, no se sube.
set PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set T=C:\NBAStreetRecomp\tools
set L=%T%\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc
set PATH=C:\DBZBT4Recomp\tools\pynuget\tools;%L%\bin;%T%\ninja;%T%\cmake\cmake-4.4.4-windows-x86_64\bin;%T%\mingit\cmd;%PATH%
set B=C:\DBZBT4Recomp\bt3mod
set P=%B%\pgo
if /i "%1"=="gen" (
  if not exist %B%\build-pgo-gen\build.ninja (
    cmake -S %B% -B %B%\build-pgo-gen -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl ^
      -DCMAKE_RC_COMPILER=llvm-rc -DPS2X_SHOW_WINDOWS_CONSOLE=OFF -DPS2X_DISABLE_PGS=ON -DPS2X_ENABLE_SCCACHE=OFF ^
      "-DCMAKE_C_FLAGS=/DWIN32 /D_WINDOWS -fprofile-instr-generate -DPS2X_PGO_GEN" ^
      "-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /EHsc -fprofile-instr-generate -DPS2X_PGO_GEN" ^
      "-DCMAKE_EXE_LINKER_FLAGS=%L%\lib\clang\20\lib\windows\clang_rt.profile-x86_64.lib" || exit /b 2
  )
  cmake --build %B%\build-pgo-gen --target ps2EntryRunner -j 20
  exit /b %errorlevel%
)
if /i "%1"=="use" (
  llvm-profdata merge -o %P%\runner.profdata %P%\*.profraw || exit /b 3
  if not exist %B%\build-pgo\build.ninja (
    cmake -S %B% -B %B%\build-pgo -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl ^
      -DCMAKE_RC_COMPILER=llvm-rc -DPS2X_SHOW_WINDOWS_CONSOLE=OFF -DPS2X_DISABLE_PGS=ON -DPS2X_ENABLE_SCCACHE=OFF ^
      "-DCMAKE_C_FLAGS=/DWIN32 /D_WINDOWS -fprofile-instr-use=%P%\runner.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin" ^
      "-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /EHsc -fprofile-instr-use=%P%\runner.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin" || exit /b 2
  )
  cmake --build %B%\build-pgo --target ps2EntryRunner -j 20
  exit /b %errorlevel%
)
echo usage: build_pgo.cmd gen ^| use
exit /b 9
