param([int]$FirstSeconds = 25, [int]$SecondSeconds = 25)
# Prueba del relevo: un juego (A) arranca con su ventana del host GS; a los $FirstSeconds le pide que deje la ventana
# (PS2X_HANDOVER_FILE) y arranca otro (B) enganchado al mismo anillo (PS2X_LIVE_ATTACH). La ventana debe seguir siendo
# la misma (mismo proceso del host) y mostrar el juego B. Capturas de pantalla y registros en logs\handover.
$R = "C:\DBZBT4Recomp"; $rt = "$R\bt3mod\build\ps2xRuntime"; $out = "$R\logs\handover"
New-Item -ItemType Directory -Force $out | Out-Null; Get-ChildItem $out -File | Remove-Item
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
function Shot($name) { $b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size); $bmp.Save("$out\$name.png"); $g.Dispose(); $bmp.Dispose() }
function Start-Game($tag, [hashtable]$extra) {
    $e = @{ PS2X_CD_IMAGE = "$env:USERPROFILE\Documents\PS2_NTSC\SLUS_219.78.DBZBT4B14REV2.iso"; PS2X_GS_LIVE = '1'
        PS2X_GSHOST = "$R\gshost\pcsx2-gsrunner.exe"; PS2X_GSHOST_ARGS = "-renderer vulkan -ini $R\gshost\dbz.ini"
        PS2X_LIVE_SERIAL = 'SLUS-21978'; PS2X_LIVE_TITLE = 'DBZ BT4 handover'; PS2X_HOST_WINDOW = '960x540'; PS2X_HOST_NOACTIVATE = '1'
        PS2X_NO_GAMEPAD = '1'; PS2X_AUTOSTART = '1'; PS2X_AUTOSTART_LEFT = '1'; PS2X_LOGFILE = "$out\$tag.log"
        PS2X_HALFSTEP = "$rt\fps60_sites.txt"; PS2X_HANDOVER_FILE = "$out\handover.req"; PS2X_LIVE_RING_FILE = "$out\ring.txt" }
    foreach ($k in $extra.Keys) { $e[$k] = $extra[$k] }
    $si = New-Object Diagnostics.ProcessStartInfo "$rt\ps2EntryRunner.exe", "`"$R\bt3mod\games\bt3\work\SLUS_216.78`""
    $si.UseShellExecute = $false; $si.WorkingDirectory = $rt
    foreach ($k in $e.Keys) { $si.EnvironmentVariables[$k] = [string]$e[$k] }
    [Diagnostics.Process]::Start($si)
}
$a = Start-Game 'A' @{}
Start-Sleep $FirstSeconds
# only OUR host: the one started with this game's ring (-livering <pid of A>), never another game's window
function Our-Hosts { @(Get-CimInstance Win32_Process -Filter "Name='pcsx2-gsrunner.exe'" | Where-Object { $_.CommandLine -match "-livering $($a.Id)\b" } | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }) }
$host1 = Our-Hosts | Select-Object -First 1
Shot 'a_before'
$ring = (Get-Content "$out\ring.txt" -ErrorAction SilentlyContinue) -split ' ' | Select-Object -First 1
"A pid $($a.Id), host pid $($host1.Id), ring '$ring'"
New-Item -ItemType File "$out\handover.req" | Out-Null
if (-not $a.WaitForExit(5000)) { "A did not hand over"; Stop-Process -Id $a.Id -Force }
"A exited: $($a.HasExited); host alive: $(-not $host1.HasExited)"
Start-Sleep 1
$b = Start-Game 'B' @{ PS2X_LIVE_ATTACH = $ring }
Start-Sleep $SecondSeconds
Shot 'b_after'
$hosts = Our-Hosts
"B pid $($b.Id) running: $(-not $b.HasExited); hosts now: $($hosts.Id -join ','); same host: $($hosts.Count -eq 1 -and $hosts[0].Id -eq $host1.Id)"
Stop-Process -Id $b.Id -Force -ErrorAction SilentlyContinue; Start-Sleep 2
$hosts | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
