# Prueba de DBZ BT4: lanza el juego en ventana N segundos, pide capturas al host y lo cierra.
#   .\run_test.ps1 -Seconds 90 -Shots 20,40,60,80 [-Fps60]
param(
    [int]$Seconds = 90,
    [double[]]$Shots = @(),
    [switch]$Fps60,
    [string]$Tag = "test",
    [hashtable]$Env = @{}
)
$R = "C:\DBZBT4Recomp"
if (-not ("Dbz.Win" -as [type])) {
    Add-Type -Name Win -Namespace Dbz -MemberDefinition '[DllImport("user32.dll")] public static extern bool IsIconic(System.IntPtr h);'
}
$rt = "$R\bt3mod\build\ps2xRuntime"
$out = "$R\logs\$Tag"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force

$env:PS2X_CD_IMAGE = "$env:USERPROFILE\Documents\PS2_NTSC\SLUS_219.78.DBZBT4B14REV2.iso"
$env:PS2X_GS_LIVE = "1"
$env:PS2X_GSHOST = "$R\gshost\pcsx2-gsrunner.exe"
$env:PS2X_GSHOST_ARGS = "-renderer vulkan -ini $R\gshost\dbz.ini"
$env:PS2X_LIVE_SERIAL = "SLUS-21978"
$env:PS2X_LIVE_TITLE = "Dragon Ball Z Budokai Tenkaichi 4"
$env:PS2X_HOST_WINDOW = "1280x720"
$env:PS2X_FPS_LOG = "1"
$env:PS2X_SHOT_DIR = $out
$env:PS2X_LOGFILE = "$out\runtime.log"
$env:PS2X_HOST_NOACTIVATE = "1"
if ($Fps60) { $env:PS2X_FPS60 = "1"; $env:PS2X_HALFSTEP = "$R\bt3mod\games\bt3\fps60_sites.txt" } else { $env:PS2X_FPS60 = "0" }
foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }

$p = Start-Process "$rt\ps2EntryRunner.exe" -ArgumentList "`"$R\bt3mod\games\bt3\work\SLUS_216.78`"" -WorkingDirectory $rt `
     -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru -WindowStyle Minimized
$t0 = Get-Date
$pending = [System.Collections.Generic.List[double]]::new(); $Shots | ForEach-Object { $pending.Add($_) }
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
    $el = ((Get-Date) - $t0).TotalSeconds
    if ($pending.Count -gt 0 -and $el -ge $pending[0]) {
        [IO.File]::WriteAllText("$out\host.req", ("shot_{0:000.0}.png" -f $pending[0]).Replace(",","."))
        $h = Get-Process pcsx2-gsrunner -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$R\*" } | Select-Object -First 1
        $state = if ($h -and $h.MainWindowHandle -ne 0) { if ([Dbz.Win]::IsIconic($h.MainWindowHandle)) { "minimizada" } else { "visible" } } else { "sin ventana" }
        Add-Content "$out\window.log" ("{0}s: {1}" -f $pending[0], $state)
        $pending.RemoveAt(0)
    }
    Start-Sleep -Milliseconds 500
}
$exited = $p.HasExited
$code = if ($exited) { $p.ExitCode } else { $null }
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.CommandLine -match "-livering $($p.Id)\b" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }   # only our host
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
"exited_by_itself=$exited code=$code after {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
Get-ChildItem $out | Select-Object Length, Name | Format-Table -AutoSize
