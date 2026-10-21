param([int]$Seconds = 140, [double]$P2Delay = 10, [string]$Out = "C:\DBZBT4Recomp\logs\video")
# Video corto del online en un solo PC: dos copias del juego conectadas (encuentro en el menu Multijugador), lado a
# lado, jugando solas (PS2X_AUTOSTART). La segunda arranca $P2Delay s despues, para que se vea "Esperando a ...".
# Graba solo la zona de las dos ventanas (ffmpeg gdigrab) y deja el mp4 en $Out; no se sube a ningun sitio.
$R = "C:\DBZBT4Recomp"
New-Item -ItemType Directory -Force $Out | Out-Null
foreach ($p in 1, 2) { $c = "$R\logs\democard$p"; if (Test-Path $c) { Remove-Item -Recurse -Force $c }; Copy-Item -Recurse "$R\logs\match_1943\netcard" $c }
$t0 = Get-Date
$port = Get-Random -Minimum 7840 -Maximum 7990   # a fresh port: a leftover game on an old one cannot answer
# the recorder, beside the test: finds this test's two host windows (started from $R\gshost after $t0 -- a real match
# uses prueba_crossplay's), puts them side by side and records that rectangle until the test ends
$rec = Start-Job -ScriptBlock {
    param($R, $Out, $t0, $Seconds, $P2Delay)
    Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W2 { [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
    [W2]::SetProcessDPIAware() | Out-Null
    $deadline = $t0.AddSeconds($P2Delay + 60); $wins = @()
    while ((Get-Date) -lt $deadline -and $wins.Count -lt 2) {
        Start-Sleep -Milliseconds 500
        $wins = @(Get-CimInstance Win32_Process -Filter "Name='pcsx2-gsrunner.exe'" |
            Where-Object { $_.ExecutablePath -eq "$R\gshost\pcsx2-gsrunner.exe" -and $_.CreationDate -gt $t0 } |
            Sort-Object CreationDate | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue } |
            Where-Object { $_ -and $_.MainWindowHandle -ne 0 })
    }
    if ($wins.Count -lt 2) { return "ventanas no encontradas ($($wins.Count))" }
    for ($i = 0; $i -lt 2; $i++) { [W2]::SetWindowPos($wins[$i].MainWindowHandle, [IntPtr](-1), 40 + $i * 980, 60, 980, 590, 0x0040) | Out-Null }
    Start-Sleep 1
    $r0 = New-Object W2+R; [W2]::GetWindowRect($wins[0].MainWindowHandle, [ref]$r0) | Out-Null
    $r1 = New-Object W2+R; [W2]::GetWindowRect($wins[1].MainWindowHandle, [ref]$r1) | Out-Null
    $w = $r1.Rt - $r0.L; $w -= $w % 2; $h = [Math]::Max($r0.B, $r1.B) - $r0.T; $h -= $h % 2
    $rest = [int]($Seconds - ((Get-Date) - $t0).TotalSeconds - 3)
    $file = Join-Path $Out ("online_windows_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".mp4")
    & "C:\NBAStreetRecomp\tools\ffmpeg\ffmpeg.exe" -y -nostdin -loglevel error -f gdigrab -framerate 30 -offset_x $r0.L -offset_y $r0.T `
        -video_size "${w}x${h}" -draw_mouse 0 -i desktop -t $rest -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p $file 2>&1 | Out-Null
    "video: $file ($w x $h, $rest s)"
} -ArgumentList $R, $Out, $t0, $Seconds, $P2Delay
$common = @{ PS2X_FRAMESTEP = '1'; PS2X_FIBERS = '1'; PS2X_RANDSEED = '10389561965450547736'; PS2X_RTC = '1767225600'
    PS2X_NET_JUMP_STOP = 'menu'; PS2X_NET_MEET = 'menu'; PS2X_NET_DELAY = 'auto'; PS2X_AUTOSTART = '1'; PS2X_AUTOSTART_LEFT = '1' }
& "$R\tools\online_pair_test.ps1" -Relay '' -Token '' -Seconds $Seconds -P2Delay $P2Delay -Shots @(($Seconds - 1)) -Env $common `
    -EnvP1 @{ PS2X_NET_LISTEN = "$port"; PS2X_MC_ROOT = "$R\logs\democard1"; PS2X_LIVE_TITLE = 'Jugador 1'; PS2X_NET_PEER_NAME = 'Jugador2' } `
    -EnvP2 @{ PS2X_NET = "127.0.0.1:$port"; PS2X_MC_ROOT = "$R\logs\democard2"; PS2X_LIVE_TITLE = 'Jugador 2'; PS2X_NET_PEER_NAME = 'Jugador1' } | Out-Null
Receive-Job (Wait-Job $rec -Timeout 30)
