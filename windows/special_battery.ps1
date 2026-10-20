# Batería de ataques especiales a 60 fps con el modo auditoría (PS2X_HSAUDIT=1): por cada personaje (fila, derechas en
# la selección), Duelo > Multijugador > Simple, J2 quieto, y en la pelea carga ki + L2+Triángulo, L2+Arriba+Triángulo y
# L2+Abajo+Triángulo. Guarda logs\battery\<fila>_<col>\ (runtime.log, capturas temporizadas) y un resumen.
param([string[]]$Picks = @('3,4'), [switch]$Fps30)
$R = "C:\DBZBT4Recomp"
$sum = "$R\logs\battery\summary.txt"
New-Item -ItemType Directory -Force "$R\logs\battery" | Out-Null
foreach ($pk in $Picks) {
    $row, $col = $pk.Split(',') | ForEach-Object { [int]$_ }
    $p = [System.Collections.Generic.List[string]]::new(); $p2 = [System.Collections.Generic.List[string]]::new()
    function P($l, [double]$t, [string]$b) { $l.Add(("{0:0.00}:{1}" -f $t, $b).Replace(',', '.')) }
    P $p 9 DOWN; P $p 9.6 DOWN; P $p 10.2 DOWN; P $p 11.5 CROSS; P $p 13.5 DOWN; P $p 15.5 CROSS; P $p 18 CROSS
    $t = 21.0
    for ($i = 0; $i -lt $row; $i++) { P $p $t DOWN; $t += 0.9 }
    $t += 0.6
    for ($i = 0; $i -lt $col; $i++) { P $p $t RIGHT; $t += 0.9 }
    $nameAt = $t + 1.2
    for ($c = [math]::Max(31.5, $t + 3); $c -le 72; $c += 3) { P $p $c CROSS; P $p2 ($c + 1.5) CROSS }
    $specials = @(@(104.5, 'L2+TRIANGLE'), @(125.5, 'L2+UP+TRIANGLE'), @(146.5, 'L2+DOWN+TRIANGLE'))
    $shotT = [System.Collections.Generic.List[string]]::new()
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $off = 36.2
    $shotT.Add(($nameAt + $off).ToString('0.00', $inv))
    foreach ($s in $specials) {
        for ($h = $s[0] - 9.5; $h -le $s[0] - 1.5; $h += 0.1) { P $p $h L2 }
        P $p $s[0] $s[1]
        foreach ($d in 0.4, 0.8, 1.2, 1.8, 2.6, 3.6, 5.0) { $shotT.Add(($s[0] + $d + $off).ToString('0.00', $inv)) }
    }
    $tag = "battery\{0}_{1}" -f $row, $col
    $env = @{PS2X_AUTOSTART = '1'; PS2X_AUTOSTART_LEFT = '1'; PS2X_AUTOSTART_FIGHT = '0'; PS2X_PAD_SCRIPT = ($p -join ','); PS2X_PAD_SCRIPT_P2 = ($p2 -join ',');
        PS2X_PAD_SCRIPT_STATE = '0x4'; PS2X_NO_GAMEPAD = '1'; PS2X_HSAUDIT = '1'; PS2X_SHOT_TIMES = ($shotT -join ',');
        PS2X_TEST_T0 = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
    if ($Fps30) { & "$PSScriptRoot\run_test.ps1" -Seconds 160 -Tag $tag -Env $env | Out-Null }
    else { & "$PSScriptRoot\run_test.ps1" -Seconds 160 -Fps60 -Tag $tag -Env $env | Out-Null }
    $log = "$R\logs\$tag\runtime.log"
    $audit = Select-String $log -Pattern '^\[hsaudit\]' | ForEach-Object Line
    Add-Content $sum ("== {0}: {1} audit lines" -f $tag, $audit.Count)
    $audit | ForEach-Object { Add-Content $sum "   $_" }
}
