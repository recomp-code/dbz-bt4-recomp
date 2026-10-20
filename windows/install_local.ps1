# Instala / actualiza el juego de este PC desde dist\DBZ_BT4_Windows (lo que hay en el zip) en C:\DBZBT4Recomp\Juego,
# sin pisar lo del jugador: DBZ_BT4.cfg, runtime\data (ELF sacado de la ISO), runtime\savedata (memory card, ajustes)
# ni los .ini que el menu del juego reescribe. La primera vez trae la memory card de la build de desarrollo y deja un
# solo acceso directo en el escritorio.
param([string]$Dest = "C:\DBZBT4Recomp\Juego")
$src = "C:\DBZBT4Recomp\dist\DBZ_BT4_Windows"
$first = -not (Test-Path "$Dest\DBZ_BT4.exe")
# 1. program files: always updated
robocopy $src $Dest /E /XF *.ini *.cfg settings.toml /XD "$src\runtime\data" /NFL /NDL /NJH /NJS /NP | Out-Null
# 2. the player's files: copied only when missing
robocopy $src $Dest *.ini settings.toml /E /XC /XN /XO /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy fallo ($LASTEXITCODE)" }
$mc = "C:\DBZBT4Recomp\bt3mod\games\bt3\savedata\BASLUS-21978DBZT4"
if ((Test-Path $mc) -and -not (Test-Path "$Dest\runtime\savedata\BASLUS-21978DBZT4")) {
    Copy-Item $mc "$Dest\runtime\savedata\" -Recurse
    "memory card copiada de la build de desarrollo"
}
if ($first) {
    $iso = "$env:USERPROFILE\Documents\PS2_NTSC\SLUS_219.78.DBZBT4B14REV2.iso"
    if (Test-Path $iso) {
        $p = Start-Process "$Dest\DBZ_BT4.exe" -ArgumentList "--iso `"$iso`"" -PassThru
        for ($i = 0; $i -lt 40 -and -not (Test-Path "$Dest\DBZ_BT4.cfg"); $i++) { Start-Sleep -Milliseconds 250 }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    $desk = [Environment]::GetFolderPath('Desktop')
    $ws = New-Object -ComObject WScript.Shell
    Get-ChildItem $desk -Filter *.lnk | Where-Object { $ws.CreateShortcut($_.FullName).TargetPath -like 'C:\DBZBT4Recomp\Jugar_DBZ*' } |
        ForEach-Object { Remove-Item $_.FullName; "acceso directo viejo quitado: $($_.Name)" }
    $s = $ws.CreateShortcut("$desk\DBZ Budokai Tenkaichi 4.lnk")
    $s.TargetPath = "$Dest\DBZ_BT4.exe"; $s.WorkingDirectory = $Dest; $s.Save()
}
"instalado en $Dest"
