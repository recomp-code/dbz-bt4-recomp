param([string]$Out, [string]$Card, [int]$Frame = 60, [hashtable]$Extra = @{})
# Boots the game offline in the online conditions (virtual clock, fixed seed and clock, a given memory card, no
# input) until $Frame, logging [dethash]/[detblock] and dumping RAM there. Two runs of this must match exactly; it
# is the quick determinism check (about 30 s) before any two-machine match.
$d = 'C:\DBZBT4Recomp\prueba_crossplay'
New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Out -File -ErrorAction SilentlyContinue | Remove-Item
$mc = "$Out\card"; if (Test-Path $mc) { Remove-Item -Recurse -Force $mc }; Copy-Item -Recurse $Card $mc   # fresh copy: new file times
$iso = (Get-Content "$d\DBZ_BT4.cfg" | Where-Object { $_ -like 'iso=*' }) -replace '^iso=', ''
$si = New-Object Diagnostics.ProcessStartInfo "$d\runtime\ps2EntryRunner.exe", "`"$d\runtime\data\SLUS_216.78`""
$si.UseShellExecute = $false; $si.WorkingDirectory = "$d\runtime"
$e = @{ PS2X_CD_IMAGE = $iso; PS2X_GS_LIVE = '1'; PS2X_GSHOST = "$d\gshost\pcsx2-gsrunner.exe"; PS2X_GSHOST_ARGS = "-renderer vulkan -ini dbz_3x.ini"
    PS2X_LIVE_SERIAL = 'SLUS-21978'; PS2X_HOST_WINDOW = '960x540'; PS2X_HOST_NOACTIVATE = '1'; PS2X_NO_GAMEPAD = '1'; PS2X_LOGFILE = "$Out\run.log"
    PS2X_HALFSTEP = "$d\runtime\fps60_sites.txt"; PS2X_FPS60 = '1'; PS2X_FRAMESTEP = '1'; PS2X_FIBERS = '1'; PS2X_DETHASH = '60'
    PS2X_DETDUMP = "$Frame"; PS2X_NET_DUMPDIR = $Out; PS2X_RANDSEED = '10389561965450547736'; PS2X_RTC = '1767225600'; PS2X_MC_ROOT = $mc }
foreach ($k in $Extra.Keys) { $e[$k] = $Extra[$k] }
foreach ($k in $e.Keys) { $si.EnvironmentVariables[$k] = [string]$e[$k] }
$p = [Diagnostics.Process]::Start($si)
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $deadline -and -not (Test-Path "$Out\ram_$Frame.bin")) { Start-Sleep 1 }
Start-Sleep 2
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.CommandLine -match 'prueba_crossplay' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Select-String "$Out\run.log" -Pattern "^\[dethash\] frame $Frame " | Select-Object -First 1 | ForEach-Object { $_.Line -replace ' vu0r=.*', '' }

