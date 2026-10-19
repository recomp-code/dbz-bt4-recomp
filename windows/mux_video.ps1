# Une el video del host (PS2X_CAPTURE, 59.94 fps constantes) con el audio del runtime (PS2X_WAVCAP) usando las marcas
# [avsync] del runtime (cada 60 frames del stream GS: bytes del WAV). Donde el juego genero frames mas lentos (cargas),
# el tramo de audio se ajusta con atempo a la duracion del video, asi la sincronia no deriva.
param([string]$Dir = "C:\DBZBT4Recomp\logs\video", [int]$FromVsync = 900, [int]$ToVsync = 0, [string]$Out = "dbz_bt4_mod.mp4",
      [double]$Tolerance = 0.004)
$ff = "C:\NBAStreetRecomp\tools\ffmpeg\ffmpeg.exe"
$hdr = [IO.File]::ReadAllBytes("$Dir\audio.wav")[0..43]
$bps = [BitConverter]::ToUInt32($hdr, 28)
if ($ToVsync -le 0) {
    $m = Select-String "$Dir\emulog.txt" -Pattern 'capture finished at vsync (\d+)' | Select-Object -Last 1
    $ToVsync = [int]$m.Matches[0].Groups[1].Value
}
$marks = Select-String "$Dir\runtime.log" -Pattern '^\[avsync\] frame (\d+) wav_bytes (\d+)' | ForEach-Object {
    [pscustomobject]@{ f = [int]$_.Matches[0].Groups[1].Value; s = [double]$_.Matches[0].Groups[2].Value / $bps } }
function AudioAt([double]$f) {
    $lo = $marks | Where-Object { $_.f -le $f } | Select-Object -Last 1
    $hi = $marks | Where-Object { $_.f -ge $f } | Select-Object -First 1
    if (-not $hi) { $hi = $lo }
    if (-not $lo) { $lo = $hi }
    if ($hi.f -eq $lo.f) { return $lo.s }
    return $lo.s + ($hi.s - $lo.s) * ($f - $lo.f) / ($hi.f - $lo.f)
}
# chunk boundaries: the capture start, every mark inside, the capture end
$bounds = @($FromVsync) + @($marks | Where-Object { $_.f -gt $FromVsync -and $_.f -lt $ToVsync } | ForEach-Object { $_.f }) + @($ToVsync)
$fps = 59.94
# merge consecutive chunks whose audio/video speed ratio is within $Tolerance
$segs = [System.Collections.Generic.List[object]]::new()
for ($i = 0; $i -lt $bounds.Count - 1; $i++) {
    $f0 = $bounds[$i]; $f1 = $bounds[$i + 1]
    $a0 = AudioAt $f0; $a1 = AudioAt $f1
    $ratio = ($a1 - $a0) / (($f1 - $f0) / $fps)
    if ($segs.Count -gt 0 -and [math]::Abs($segs[-1].ratio - $ratio) -lt $Tolerance) {
        $s = $segs[-1]; $s.f1 = $f1; $s.a1 = $a1; $s.ratio = ($s.a1 - $s.a0) / (($s.f1 - $s.f0) / $fps)
    } else {
        $segs.Add([pscustomobject]@{ f0 = $f0; f1 = $f1; a0 = $a0; a1 = $a1; ratio = $ratio })
    }
}
$inv = [Globalization.CultureInfo]::InvariantCulture
$parts = @(); $labels = @(); $n = 0
foreach ($s in $segs) {
    $r = [math]::Min(2.0, [math]::Max(0.5, $s.ratio))
    $parts += ("[1:a]atrim=start={0}:end={1},asetpts=PTS-STARTPTS,atempo={2}[a{3}]" -f $s.a0.ToString('0.######', $inv), $s.a1.ToString('0.######', $inv), $r.ToString('0.######', $inv), $n)
    $labels += "[a$n]"; $n++
}
$filter = ($parts -join ';') + ';' + ($labels -join '') + "concat=n=${n}:v=0:a=1[aout]"
$filterFile = "$Dir\audio_filter.txt"
[IO.File]::WriteAllText($filterFile, $filter)
"{0} audio segments (ratios {1:0.000}..{2:0.000}), video {3:0.0} s" -f $n, ($segs.ratio | Measure-Object -Minimum).Minimum,
    ($segs.ratio | Measure-Object -Maximum).Maximum, (($ToVsync - $FromVsync) / $fps)
& $ff -hide_banner -loglevel error -y -i "$Dir\video_raw.mp4" -i "$Dir\audio.wav" -filter_complex_script $filterFile `
    -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 256k -movflags +faststart -shortest "$Dir\$Out"
if ($LASTEXITCODE -ne 0) { throw "ffmpeg fallo ($LASTEXITCODE)" }
Get-Item "$Dir\$Out" | Select-Object Length, FullName
