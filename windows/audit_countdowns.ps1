# Audit of the fps60 countdown rules ('d'/'e' in fps60_sites.txt): for each site, the field it writes (offset from a base
# register), and every place in the recompiled code that loads that offset into the FPU (lwc1 + cvt.s.w) and divides it
# (div.s): that is a "counter / duration" progress, and the divisor's field has to be doubled together with the counter.
# Output: one line per site and per division found, with the divisor's source (another offset of the same base, a
# constant or something else).
param([string]$Runner = "C:\DBZBT4Recomp\bt3mod\ps2xRuntime\src\runner", [string]$Sites = "C:\DBZBT4Recomp\bt3mod\games\bt3\fps60_sites.txt")
$ErrorActionPreference = 'Stop'
$files = Get-ChildItem $Runner -Filter *.cpp
# index: pc -> (file, line) for every disassembly comment line "// 0x<pc>: <word>  <mnemonic> <operands>"
$asm = @{}; $byFile = @{}
foreach ($f in $files) {
    $lines = [IO.File]::ReadAllLines($f.FullName)
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($l in $lines) {
        if ($l -match '^\s+// 0x([0-9a-f]+): 0x[0-9a-f]+\s+(\S+)\s*(.*?)(\s+\(Delay Slot\))?$') {
            $o = [pscustomobject]@{ pc = [Convert]::ToUInt32($Matches[1], 16); op = $Matches[2]; args = $Matches[3].Trim() }
            $list.Add($o)
            if (-not $asm.ContainsKey($o.pc)) { $asm[$o.pc] = $o }
        }
    }
    $byFile[$f.Name] = $list
}
"indexed {0:N0} instructions" -f $asm.Count
# all instructions in pc order (functions overlap in the generated files; dedupe by pc)
$all = $asm.Values | Sort-Object pc
$pos = @{}; $lwc1 = @{}
for ($i = 0; $i -lt $all.Count; $i++) { $pos[$all[$i].pc] = $i
    if ($all[$i].op -eq 'lwc1' -and $all[$i].args -match '^\$f\d+, (-?0x[0-9A-Fa-f]+|\d+)\(') { $key = $Matches[1]; if (-not $lwc1.ContainsKey($key)) { $lwc1[$key] = [System.Collections.Generic.List[int]]::new() }; $lwc1[$key].Add($i) } }

$dsites = Get-Content $Sites | Where-Object { $_ -match '^0x([0-9a-f]+) ([de])\b' } | ForEach-Object { [pscustomobject]@{ pc = [Convert]::ToUInt32($Matches[1], 16); kind = $Matches[2] } }
foreach ($s in $dsites) {
    if (-not $pos.ContainsKey($s.pc)) { "0x{0:x} {1}: not in the recompiled code" -f $s.pc, $s.kind; continue }
    # the store: the site itself or one of the next 2 instructions (branch + delay slot)
    $i = $pos[$s.pc]; $st = $null
    for ($k = 0; $k -le 2 -and -not $st; $k++) { $x = $all[$i + $k]; if ($x.op -in 'sw', 'sh', 'sb' -and $x.args -match '^(\$\w+), (-?0x[0-9A-Fa-f]+|\d+)\((\$\w+)\)$') { $st = $x } }
    if (-not $st) { "0x{0:x} {1}: no store found next to it" -f $s.pc, $s.kind; continue }
    $null = $st.args -match '^(\$\w+), (-?0x[0-9A-Fa-f]+|\d+)\((\$\w+)\)$'; $off = $Matches[2]
    $uses = @()
    $cands = if ($lwc1.ContainsKey($off)) { $lwc1[$off] } else { @() }
    foreach ($j in $cands) {
        $x = $all[$j]
        if ($x.op -ne 'lwc1' -or $x.args -notmatch ("^(\`$f\d+), " + [regex]::Escape($off) + "\((\`$\w+)\)$")) { continue }
        $freg = $Matches[1]; $base = $Matches[2]
        # cvt.s.w on it within 4, then a div.s using it within 8
        $cvt = $false; $div = $null
        for ($k = 1; $k -le 10 -and ($j + $k) -lt $all.Count; $k++) {
            $y = $all[$j + $k]
            if ($y.op -eq 'cvt.s.w' -and $y.args -match ("^" + [regex]::Escape($freg) + ", " + [regex]::Escape($freg) + "$")) { $cvt = $true }
            if ($cvt -and $y.op -eq 'div.s' -and $y.args -match ("^(\`$f\d+), " + [regex]::Escape($freg) + ", (\`$f\d+)$")) { $div = $y; break }
        }
        if (-not $div) { continue }
        $null = $div.args -match '^(\$f\d+), (\$f\d+), (\$f\d+)$'; $den = $Matches[3]
        # where the denominator came from: look back up to 14 instructions for its producer
        $src = '?'
        for ($k = 1; $k -le 14 -and ($j + 10 - $k) -ge 0; $k++) {
            $y = $all[$pos[$div.pc] - $k]
            if ($y.args -match ("^" + [regex]::Escape($den) + ", ")) {
                if ($y.op -eq 'lwc1') { $src = "lwc1 " + $y.args }
                elseif ($y.op -eq 'cvt.s.w') {   # int: find the mtc1 / lwc1 feeding it
                    for ($m = 1; $m -le 10; $m++) { $z = $all[$pos[$y.pc] - $m]; if ($z.args -match ("^" + [regex]::Escape($den) + ", ") -and $z.op -eq 'lwc1') { $src = "int lwc1 " + $z.args; break }
                        if ($z.op -eq 'mtc1' -and $z.args -match ("^(\`$\w+), " + [regex]::Escape($den) + "$")) { $g = $Matches[1]
                            for ($q = 1; $q -le 12; $q++) { $w = $all[$pos[$z.pc] - $q]; if ($w.args -match ("^" + [regex]::Escape($g) + ", ")) { $src = "int " + $w.op + " " + $w.args; break } }; break } }
                }
                else { $src = $y.op + " " + $y.args }
                break
            }
        }
        $uses += ("    0x{0:x}: {1} / {2}  (div at 0x{3:x}, base {4})" -f $x.pc, "lwc1 $($x.args)", $src, $div.pc, $base)
    }
    "0x{0:x} {1}: store {2} {3} -> {4} division(s)" -f $s.pc, $s.kind, $st.op, $st.args, $uses.Count
    $uses
}
