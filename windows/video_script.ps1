# Guion de botones del video (segundos desde el menu principal, PS2X_PAD_SCRIPT_STATE=0x4). Devuelve @(script, ultimo_tiempo).
# Medido en esta build: en la seleccion la fila inicial es "Goku (Inicio)"; Goku Black / Jiren = 14 DOWN, Hit = 15,
# Broly = 13, la fila de Beerus = 6, los Goku/Vegeta de Super = 4. P1 necesita 4 CROSS (personaje, traje, variante,
# confirmar) y P2 3; despues viene "Seleccion de Mapa" (11 filas de 7, la inicial es Yermos; UP desde ahi = Ciudad (Oeste)).
$p = [System.Collections.Generic.List[string]]::new()
function P([double]$t, [string]$b) { $p.Add(("{0:0.00}:{1}" -f $t, $b).Replace(',', '.')) }
# unlock everything: hold L1+R1, Down Right Triangle Down Left Triangle Up
for ($t = 2.0; $t -le 6.6; $t += 0.1) { P $t 'L1+R1' }
$seq = 'DOWN', 'RIGHT', 'TRIANGLE', 'DOWN', 'LEFT', 'TRIANGLE', 'UP'
for ($i = 0; $i -lt 7; $i++) { P (3.0 + 0.4 * $i) ("L1+R1+" + $seq[$i]) }
# Duelo -> 1 Jugador -> Simple
P 9.0 'DOWN'; P 9.6 'DOWN'; P 10.2 'DOWN'; P 11.5 'CROSS'; P 14.0 'CROSS'; P 17.0 'CROSS'
# character tour (P1 cursor at row 0 / index 0): a full RIGHT cycle (7) on each of the mod's rows
$t = 21.0; $row = 0
foreach ($target in 4, 6, 13, 14, 15) {
    while ($row -lt $target) { P $t 'DOWN'; $t += 0.75; $row++ }
    $t += 0.8
    for ($k = 0; $k -lt 7; $k++) { P $t 'RIGHT'; $t += 1.15 }
    $t += 0.5
}
# P1 = Jiren (row 14, index 5)
P $t 'UP'; $t += 1.0
for ($k = 0; $k -lt 5; $k++) { P $t 'RIGHT'; $t += 0.7 }
# A confirmation ~1 s after the last cursor move is swallowed: wait 2 s. Then character, costume, outfit.
$t += 2.0
for ($k = 0; $k -lt 3; $k++) { P $t 'CROSS'; $t += 3.0 }
# P2 = Goku Black (row 14 = 6 UP of the 20 rows, index 0); the P2 cursor starts on Gohan (Nino), row 0 index 5
$t += 1.0
for ($k = 0; $k -lt 6; $k++) { P $t 'UP'; $t += 0.75 }
$t += 0.5
for ($k = 0; $k -lt 5; $k++) { P $t 'LEFT'; $t += 0.7 }
$t += 2.0
for ($k = 0; $k -lt 3; $k++) { P $t 'CROSS'; $t += 3.0 }
# stage tour: rows 10, 9, 8, 7, 6 (UP from the first row wraps to the last), a full RIGHT cycle each
$t += 1.0
foreach ($r in 1..5) {
    P $t 'UP'; $t += 1.0
    # 6 stages + the music button per row; row 6 stops on its index 5 = "Torneo del Poder (Final)"
    $n = if ($r -eq 5) { 5 } else { 7 }
    for ($k = 0; $k -lt $n; $k++) { P $t 'RIGHT'; $t += 1.0 }
    $t += 0.3
}
$t += 2.0; P $t 'CROSS'; $t += 1.0
$script = $p -join ','
return @($script, $t)
