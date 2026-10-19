# Entorno de compilacion de DBZ BT4 (reusa las herramientas portatiles de C:\NBAStreetRecomp\tools).
# Uso: . C:\DBZBT4Recomp\tools\env.ps1
$T = "C:\NBAStreetRecomp\tools"
$D = "C:\DBZBT4Recomp\tools"
$env:Path = "$D\pynuget\tools;$D\pynuget\tools\Scripts;$T\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin;$T\ninja;" +
            "$T\cmake\cmake-4.4.4-windows-x86_64\bin;$T\mingit\cmd;C:\Program Files\7-Zip;" + $env:Path
# PS2X_SETUP_* para setup.py de BT3-Recomp: nunca preguntar, generador Ninja + clang-cl.
$env:PS2X_SETUP_GENERATOR = "ninja"
$env:PYTHONUTF8 = "1"
