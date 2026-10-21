# Prueba online en este PC: dos copias del juego conectadas por el relay de recomp-online (servidor local o
# remoto) con un código de partida. Cada copia: su log y sus capturas en logs\online\p1 y p2.
#   .\online_pair_test.ps1 -Relay 127.0.0.1:7777 -Token <32 hex> [-Seconds 200] [-Shots 60,90,120] [-Fps60]
#   -EnvP1 / -EnvP2: variables for one side only. An honest test gives the sides DIFFERENT input (e.g. -EnvP2
#   @{PS2X_AUTOSTART='0'}: P2 stands still): with the same auto-play on both, a lost remote input looks identical.
param([string]$Relay, [string]$Token, [int]$Seconds = 200, [double[]]$Shots = @(60, 90, 120, 150, 180), [switch]$Fps60, [hashtable]$Env = @{},
      [hashtable]$EnvP1 = @{}, [hashtable]$EnvP2 = @{}, [double]$P2Delay = 1.5, [switch]$P2Slow)
#   -P2Slow: P2 runs on 2 cores at below-normal priority, like a much slower PC. Both sides hash their game state
#   every 60 frames (PS2X_DETHASH=60) and compare: "*** DESYNC at frame N" names the first difference.
#   -P2Delay: seconds between starting P1 and P2 (a slower machine reaches every screen later).
$R = "C:\DBZBT4Recomp"
$rt = "$R\bt3mod\build\ps2xRuntime"
$procs = @()
foreach ($p in 1, 2) {
    $out = "$R\logs\online\p$p"; New-Item -ItemType Directory -Force $out | Out-Null; Get-ChildItem $out -File | Remove-Item
    $e = @{
        PS2X_CD_IMAGE = "$env:USERPROFILE\Documents\PS2_NTSC\SLUS_219.78.DBZBT4B14REV2.iso"; PS2X_GS_LIVE = '1'
        PS2X_GSHOST = "$R\gshost\pcsx2-gsrunner.exe"; PS2X_GSHOST_ARGS = "-renderer vulkan -ini $R\gshost\dbz.ini"
        PS2X_LIVE_SERIAL = 'SLUS-21978'; PS2X_LIVE_TITLE = "DBZ BT4 online P$p"; PS2X_HOST_WINDOW = '960x540'; PS2X_HOST_NOACTIVATE = '1'
        PS2X_NO_GAMEPAD = '1'; PS2X_FPS_LOG = '1'; PS2X_LOGFILE = "$out\runtime.log"; PS2X_SHOT_DIR = $out
        PS2X_AUTOSTART = '1'; PS2X_AUTOSTART_LEFT = '1'
        PS2X_NET_RELAY = $Relay; PS2X_NET_TOKEN = $Token; PS2X_NET_PLAYER = "$p"; NET_OVERLAY = '1'; PS2X_NET_JUMP = '1'
        PS2X_FPS60 = $(if ($Fps60) { '1' } else { '0' }); PS2X_HALFSTEP = "$rt\fps60_sites.txt"; PS2X_DETHASH = '60'
        # what the launcher sets online (profiles.go dbzEnv, game.go): without it the two games differ from frame 60
        PS2X_FRAMESTEP = '1'; PS2X_FIBERS = '1'; PS2X_RANDSEED = '12345'; PS2X_RTC = '1767225600'; PS2X_UNLOCK_ALL = '1'
    }
    foreach ($k in $Env.Keys) { $e[$k] = $Env[$k] }
    $side = if ($p -eq 1) { $EnvP1 } else { $EnvP2 }
    foreach ($k in $side.Keys) { $e[$k] = $side[$k] }
    $si = New-Object Diagnostics.ProcessStartInfo "$rt\ps2EntryRunner.exe", "`"$R\bt3mod\games\bt3\work\SLUS_216.78`""
    $si.UseShellExecute = $false; $si.WorkingDirectory = $rt
    foreach ($k in $e.Keys) { $si.EnvironmentVariables[$k] = [string]$e[$k] }
    [IO.File]::WriteAllText("$out\env.txt", (($e.Keys | Sort-Object | % { "$_=$(([string]$e[$_]).Substring(0, [Math]::Min(60, ([string]$e[$_]).Length)))" }) -join "`n"))
    $pr = [Diagnostics.Process]::Start($si); $procs += $pr
    if ($p -eq 2 -and $P2Slow) { $pr.ProcessorAffinity = [IntPtr]3; $pr.PriorityClass = 'BelowNormal' }   # a slower machine: 2 cores
    if ($p -eq 1) { Start-Sleep -Milliseconds ([int]($P2Delay * 1000)) }
}
$t0 = Get-Date; $pending = [System.Collections.Generic.List[double]]::new(); $Shots | ForEach-Object { $pending.Add($_) }
while (((Get-Date) - $t0).TotalSeconds -lt $Seconds -and ($procs | Where-Object { -not $_.HasExited })) {
    if ($pending.Count -gt 0 -and ((Get-Date) - $t0).TotalSeconds -ge $pending[0]) {
        foreach ($p in 1, 2) { [IO.File]::WriteAllText("$R\logs\online\p$p\host.req", ("shot_{0:000}.png" -f $pending[0])) }
        $pending.RemoveAt(0)
    }
    Start-Sleep -Milliseconds 300
}
foreach ($pr in $procs) { if (-not $pr.HasExited) { Stop-Process -Id $pr.Id -Force -ErrorAction SilentlyContinue } }
# only the hosts of OUR two games (-livering <their pid>), never the window of a real match running beside the test
$ours = $procs | ForEach-Object { $_.Id }
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and ($_.CommandLine -match '-livering (\d+)') -and ($ours -contains [int]$Matches[1]) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
foreach ($p in 1, 2) {
    "== p$p"
    Select-String "$R\logs\online\p$p\runtime.log" -Pattern '\[netplay\]|\[netview\]|DESYNC|\[netjump\]' | Select-Object -First 12 | ForEach-Object Line
}
