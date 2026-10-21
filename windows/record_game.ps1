param([string]$Out = "C:\DBZBT4Recomp\logs\video", [int]$MaxSeconds = 480, [int]$WaitSeconds = 900)
# Graba en video la ventana del juego (el host GS, pcsx2-gsrunner) en cuanto aparece, hasta que se cierra o pasan
# $MaxSeconds. Solo la zona de esa ventana, no el resto de la pantalla. El archivo se queda en este PC ($Out).
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W { [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[W]::SetProcessDPIAware() | Out-Null
$ff = "C:\NBAStreetRecomp\tools\ffmpeg\ffmpeg.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$t0 = Get-Date; $p = $null
while (((Get-Date) - $t0).TotalSeconds -lt $WaitSeconds) {
    $p = Get-Process pcsx2-gsrunner -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($p) { break }; Start-Sleep -Milliseconds 500
}
if (-not $p) { "no apareció la ventana del juego"; exit 1 }
Start-Sleep 1
$r = New-Object W+R; [W]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$w = ($r.Rt - $r.L) - (($r.Rt - $r.L) % 2); $h = ($r.B - $r.T) - (($r.B - $r.T) % 2)
$file = Join-Path $Out ("windows_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".mp4")
$args = "-y -nostdin -loglevel error -f gdigrab -framerate 30 -offset_x $($r.L) -offset_y $($r.T) -video_size ${w}x${h} -draw_mouse 0 -i desktop -t $MaxSeconds -c:v libx264 -preset veryfast -pix_fmt yuv420p `"$file`""
$rec = Start-Process -FilePath $ff -ArgumentList $args -PassThru -WindowStyle Hidden
while (-not $p.HasExited -and -not $rec.HasExited) { Start-Sleep 1 }
if (-not $rec.HasExited) { Stop-Process -Id $rec.Id; Start-Sleep 2 }   # ffmpeg cerrado a la fuerza: el mp4 puede quedar sin índice
"grabado: $file ($w x $h)"
