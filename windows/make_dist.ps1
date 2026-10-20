# Arma el paquete listo para jugar: dist\DBZ_BT4_Windows\ (y su .zip). No incluye la ISO, el ELF ni datos del disco:
# el launcher (DBZ_BT4.exe) los saca de la ISO del jugador la primera vez.
#   runtime\   ps2EntryRunner.exe (el juego recompilado) + DLLs (FFmpeg, VC++), assets\ y savedata\settings.toml de BT3-Recomp
#   runtime\data\   lo llena el launcher (ELF del disco); runtime\savedata\ = memory card
#   gshost\    pcsx2-gsrunner (GS de PCSX2 con DLSS/FSR) + resources + presets dbz*.ini
param([switch]$NoZip)
$ErrorActionPreference = 'Stop'
$R = "C:\DBZBT4Recomp"
$dist = "$R\dist\DBZ_BT4_Windows"
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Force "$dist\runtime\data", "$dist\runtime\savedata", "$dist\gshost" | Out-Null

$rt = "$R\bt3mod\build\ps2xRuntime"
Copy-Item "$rt\ps2EntryRunner.exe", "$rt\fps60_sites.txt" "$dist\runtime"
# FFmpeg for the FMVs: the runner imports avcodec/avformat/avutil/swscale (+ swresample); avdevice/avfilter are unused
Get-ChildItem "$rt\*.dll" | Where-Object { $_.Name -notmatch '^(avdevice|avfilter)-' } | Copy-Item -Destination "$dist\runtime"
Copy-Item -Recurse "$rt\assets" "$dist\runtime\assets"
Copy-Item "$rt\savedata\settings.toml" "$dist\runtime\savedata"
$crt = Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT" | Select-Object -Last 1
foreach ($d in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item "$($crt.FullName)\$d" "$dist\runtime"; Copy-Item "$($crt.FullName)\$d" "$dist\gshost"
}

# GS host: the exe, its DLLs, resources and the presets; no debug symbols, caches, logs or capture files.
$gs = "$R\gshost"
# (PCSX2 only loads FFmpeg for its video capture, which a player does not need: those DLLs stay out)
Get-ChildItem $gs -File | Where-Object { $_.Extension -in '.exe', '.dll' -and $_.Name -notmatch '^(av[a-z]+|sw[a-z]+)-\d+\.dll$' } |
    Copy-Item -Destination "$dist\gshost"
Copy-Item -Recurse "$gs\resources" "$dist\gshost\resources"
New-Item -ItemType File "$dist\gshost\portable.ini" | Out-Null
# presets from the repository (gshost\*.ini on this PC are rewritten by the in-game menu)
$pr = "$R\dbz-bt4-recomp\windows\gshost"
Copy-Item "$pr\dbz.ini", "$pr\dbz_dlss.ini" "$dist\gshost"
# 3x preset for mid-range GPUs (texture offset of the 3x row of UserHacks_TCOffsetByScale)
(Get-Content "$pr\dbz.ini") -replace '^upscale_multiplier = 6', 'upscale_multiplier = 3' `
    -replace '^UserHacks_TCOffset([XY]) = 500', 'UserHacks_TCOffset$1 = 425' `
    -replace '^; Windows / Vulkan\. 6x = 3840x2688 interno \(supermuestreo en 1440p\)\.', '; Windows / Vulkan. Preset 3x = 1536x1344 interno (equilibrado).' |
    Set-Content "$dist\gshost\dbz_3x.ini" -Encoding ascii
# keep the pristine presets so the launcher can reset them (the host rewrites the ini when F1 options change)
New-Item -ItemType Directory "$dist\gshost\presets" | Out-Null
Copy-Item "$dist\gshost\dbz*.ini" "$dist\gshost\presets"
# DLSS 5 preset (Direct3D 12 + DLSS, the neural pass on top) and its ReShade.ini; the launcher builds gshost_dlss5\ from
# gshost\ plus DLSS 5 Swapper's ReShade / RenoDX DLSS 5 / nvngx_dlssnr.dll, none of which ship here.
(Get-Content "$pr\dbz_dlss.ini") -replace '^Renderer = 14', 'Renderer = 15' | Set-Content "$dist\gshost\presets\dbz_dlss_dx12.ini" -Encoding ascii
Get-Content "$R\gshost_hooktest\ReShade.ini" | Where-Object { $_ -notmatch '^IntermediateCachePath=' } |
    Set-Content "$dist\gshost\presets\ReShade.ini" -Encoding ascii

# launcher
& "$PSScriptRoot\build_launcher.ps1" -Out "$dist\DBZ_BT4.exe"
Copy-Item "$R\dbz-bt4-recomp\windows\LEEME.txt" "$dist\LEEME.txt"

$sum = (Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum
"dist: {0:N0} MB" -f ($sum / 1MB)
if (-not $NoZip) {
    $zip = "$R\dist\DBZ_BT4_Windows.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    & "C:\NBAStreetRecomp\tools\7zip\x64\7za.exe" a -tzip -mx=7 $zip $dist | Select-Object -Last 2
    "zip: {0:N0} MB" -f ((Get-Item $zip).Length / 1MB)
}
