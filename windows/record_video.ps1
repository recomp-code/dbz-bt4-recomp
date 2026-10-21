# Graba un video de DBZ BT4 (mod) con el codigo de "desbloquear todo", un recorrido por los personajes y escenarios
# del mod y una pelea a 60 fps. Video: el host PCSX2 (PS2X_CAPTURE, NVENC); audio: el runtime (PS2X_WAVCAP);
# sincronizados con las marcas [avsync] (frame del stream GS <-> bytes del WAV). Resultado: logs\video\dbz_bt4_mod.mp4
param([int]$Width = 2560, [int]$Height = 1440, [int]$BitrateK = 50000, [int]$FromVsync = 1200, [double]$Seconds = 215)
$R = "C:\DBZBT4Recomp"
$out = "$R\logs\video"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force

# GS settings: 6x internal, the DBZ fixes, H.264 NVENC capture without the host's (silent) audio.
$ini = "$R\gshost\dbz_capture.ini"
$base = Get-Content "$R\gshost\dbz.ini" | Where-Object { $_ -notmatch '^(VideoCapture|EnableAudioCapture|OsdShow)' }
$base + @('OsdShowFPS = false', 'VideoCaptureCodec = h264_nvenc', "VideoCaptureBitrate = $BitrateK", 'EnableAudioCapture = false',
          'EnableVideoCaptureParameters = true', 'VideoCaptureParameters = preset=p7:rc=vbr:cq=16:profile=high') |
    Set-Content $ini -Encoding ascii

$gen = & "$PSScriptRoot\video_script.ps1"; $script = $gen[0]; $t = $gen[1]
"script: {0} presses, last at {1:0.0} s after the main menu" -f $p.Count, $t

$frames = [int](($Seconds) * 59.94)
$env:PS2X_CD_IMAGE = "$env:USERPROFILE\Documents\PS2_NTSC\SLUS_219.78.DBZBT4B14REV2.iso"
$env:PS2X_GS_LIVE = "1"
$env:PS2X_GSHOST = "$R\gshost\pcsx2-gsrunner.exe"
$env:PS2X_GSHOST_ARGS = "-renderer vulkan -ini $ini"
$env:PS2X_LIVE_SERIAL = "SLUS-21978"
$env:PS2X_LIVE_TITLE = "Dragon Ball Z Budokai Tenkaichi 4"
$env:PS2X_HOST_WINDOW = "1920x1080"
$env:PS2X_HOST_NOACTIVATE = "1"
$env:PS2X_NO_GAMEPAD = "1"
$env:PS2X_FPS_LOG = "1"
$env:PS2X_FPS60 = "1"; $env:PS2X_HALFSTEP = "$R\bt3mod\games\bt3\fps60_sites.txt"
$env:PS2X_AUTOSTART = "1"; $env:PS2X_AUTOSTART_LEFT = "1"
$env:PS2X_PAD_SCRIPT = $script; $env:PS2X_PAD_SCRIPT_STATE = "0x4"
$env:PS2X_LOGFILE = "$out\runtime.log"
$env:PS2X_WAVCAP = "$out\audio.wav"
$env:PS2X_CAPTURE = "$out\video_raw.mp4"; $env:PS2X_CAPTURE_FROM = "$FromVsync"; $env:PS2X_CAPTURE_FRAMES = "$frames"
$env:PS2X_CAPTURE_SIZE = "${Width}x${Height}"

$rt = "$R\bt3mod\build\ps2xRuntime"
$proc = Start-Process "$rt\ps2EntryRunner.exe" -ArgumentList "`"$R\bt3mod\games\bt3\work\SLUS_216.78`"" -WorkingDirectory $rt -PassThru
$deadline = (Get-Date).AddSeconds(36 + $t + 90)
$emulog = "$R\gshost\logs\emulog.txt"
while (-not $proc.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep 2
    if ((Test-Path $emulog) -and (Select-String $emulog -Pattern 'capture finished' -Quiet)) { Start-Sleep 3; break }
}
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.CommandLine -match "-livering $($proc.Id)\b" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }   # only our host, never a real match's window
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
Copy-Item $emulog "$out\emulog.txt" -ErrorAction SilentlyContinue
Select-String "$out\emulog.txt" -Pattern 'capture' | ForEach-Object Line
