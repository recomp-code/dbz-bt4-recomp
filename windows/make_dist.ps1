# Arma el paquete listo para jugar: dist\DBZ_BT4_Windows\ (y su .zip). No incluye la ISO, el ELF ni datos del disco:
# el launcher (DBZ_BT4.exe) los saca de la ISO del jugador la primera vez.
#   runtime\   ps2EntryRunner.exe (el juego recompilado) + DLLs (FFmpeg, VC++), assets\ y savedata\settings.toml de BT3-Recomp
#   runtime\data\   lo llena el launcher (ELF del disco); runtime\savedata\ = memory card
#   runtime\dlss\   nvngx_dlss.dll incluida (el renderizador nativo hace DLSS / FSR 2 solo; sin host GS de PCSX2 desde el pack 2.5)
# -Runtime: the runner build to pack (the native renderer + PGO build: bt3mod\build-pgo\ps2xRuntime, see build_pgo.cmd)
param([switch]$NoZip, [string]$Server = "https://nbas3.xellrecomp.party", [string]$Runtime = "C:\DBZBT4Recomp\bt3mod\build\ps2xRuntime", [string]$Go = "C:\DBZBT4Recomp\tools\go\bin\go.exe")
$ErrorActionPreference = 'Stop'
$R = "C:\DBZBT4Recomp"
$dist = "$R\dist\DBZ_BT4_Windows"
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Force "$dist\runtime\data", "$dist\runtime\savedata" | Out-Null

$rt = $Runtime
Copy-Item "$rt\ps2EntryRunner.exe", "$rt\fps60_sites.txt" "$dist\runtime"
# FFmpeg for the FMVs: the runner imports avcodec/avformat/avutil/swscale (+ swresample); avdevice/avfilter are unused
Get-ChildItem "$rt\*.dll" | Where-Object { $_.Name -notmatch '^(avdevice|avfilter)-|^nvngx' } | Copy-Item -Destination "$dist\runtime"   # (DLSS: the launcher puts it there from runtime\dlss or DLSS\)
Copy-Item -Recurse "$rt\assets" "$dist\runtime\assets"
# the default settings (the release build's first-run file), with the HUD pinned to the window's edges as the PCSX2 host
# draws it ([parity]: an explicit layout = 0 in the shipped file overrode that default)
$st = if (Test-Path "$rt\savedata\settings.toml") { "$rt\savedata\settings.toml" } else { "$R\bt3mod\build\ps2xRuntime\savedata\settings.toml" }
[IO.File]::WriteAllText("$dist\runtime\savedata\settings.toml", ((Get-Content $st) -replace '^layout = 0', 'layout = 1') -join "`n", (New-Object Text.UTF8Encoding($false)))   # (no BOM)
$crt = Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT" | Select-Object -Last 1
foreach ($d in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item "$($crt.FullName)\$d" "$dist\runtime"
}

# DLSS: the native renderer runs it itself. The bundled nvngx_dlss.dll lives in runtime\dlss\ (once: it is 59 MB); on every
# start the launcher puts it, or the player's own from DLSS\, next to the runner. No GS host (PCSX2) since pack 2.5: the
# runtime's native Vulkan renderer is the only one.
New-Item -ItemType Directory "$dist\runtime\dlss" | Out-Null
Copy-Item "$R\gshost\nvngx_dlss.dll" "$dist\runtime\dlss\"
New-Item -ItemType Directory "$dist\DLSS" | Out-Null
Set-Content "$dist\DLSS\LEEME.txt" -Encoding ascii -Value @(
    "Pon aqui tu DLL de DLSS (o arrastrala sobre la ventana del launcher) y el juego la usa sola:",
    "  nvngx_dlss.dll       DLSS (reescalado). Si hay varias, gana la version mas nueva. Si la quitas, vuelve la incluida.",
    "Se reconoce por su informacion de version, asi que el nombre del archivo da igual.")

# launcher: the Recomp launcher (Go + Wails, C:\RecompOnline\launcher), online server built in
Push-Location "C:\RecompOnline\launcher"
$env:GOTOOLCHAIN = 'local'
& $Go build -tags desktop,production -trimpath `
    -ldflags "-H windowsgui -s -w -X main.defaultServer=$Server" -o "$dist\DBZ_BT4.exe" .
$ok = $?
Pop-Location
if (-not $ok) { throw "launcher build failed" }
Copy-Item "$R\dbz-bt4-recomp\windows\LEEME.txt" "$dist\LEEME.txt"

$sum = (Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum
"dist: {0:N0} MB" -f ($sum / 1MB)
if (-not $NoZip) {
    $zip = "$R\dist\DBZ_BT4_Windows.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    & "C:\NBAStreetRecomp\tools\7zip\x64\7za.exe" a -tzip -mx=7 $zip $dist | Select-Object -Last 2
    "zip: {0:N0} MB" -f ((Get-Item $zip).Length / 1MB)
}
