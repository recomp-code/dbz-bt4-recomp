# Second pass of the countdown audit: for each 'd'/'e' site, only the generated function that contains it. Every div.s
# whose operands come (through cvt.s.w) from a load of the counter's offset -- lwc1 directly, or lw + mtc1 -- is listed
# with both operands' sources, so a "counter / duration" pair inside the same function (the Vegeta GT camera shape) shows.
param([string]$Runner = "C:\DBZBT4Recomp\bt3mod\ps2xRuntime\src\runner", [string]$Sites = "C:\DBZBT4Recomp\bt3mod\games\bt3\fps60_sites.txt")
$re = '^\s+// 0x([0-9a-f]+): 0x[0-9a-f]+\s+(\S+)\s*(.*?)(\s+\(Delay Slot\))?$'
$dsites = Get-Content $Sites | Where-Object { $_ -match '^0x([0-9a-f]+) ([de])\b' } | ForEach-Object { [pscustomobject]@{ pc = $Matches[1]; kind = $Matches[2] } }
$files = Get-ChildItem $Runner -Filter *.cpp
foreach ($s in $dsites) {
    $hit = $files | Select-String -Pattern "// 0x$($s.pc):" -List | Select-Object -First 1
    if (-not $hit) { "0x{0} {1}: not found" -f $s.pc, $s.kind; continue }
    $ins = foreach ($l in [IO.File]::ReadAllLines($hit.Path)) { if ($l -match $re) { [pscustomobject]@{ pc = $Matches[1]; op = $Matches[2]; a = $Matches[3].Trim() } } }
    $ins = @($ins)
    $si = [Array]::FindIndex($ins, [Predicate[object]]{ param($x) $x.pc -eq $s.pc })
    $st = $null; for ($k = 0; $k -le 2; $k++) { $x = $ins[$si + $k]; if ($x.op -in 'sw', 'sh', 'sb' -and $x.a -match '^(\$\w+), (-?0x[0-9A-Fa-f]+|\d+)\((\$\w+)\)$') { $st = $x; $off = $Matches[2]; break } }
    if (-not $st) { "0x{0} {1}: no store next to it" -f $s.pc, $s.kind; continue }
    # trace a float register back (within 16 instrs) to its source: "load OFF(base)" or "const" or "?"
    function Src([int]$at, [string]$freg) {
        for ($k = 1; $k -le 16 -and $at - $k -ge 0; $k++) {
            $y = $ins[$at - $k]
            if ($y.a -notmatch ("^" + [regex]::Escape($freg) + ", ")) { continue }
            if ($y.op -eq 'lwc1') { return "lwc1 " + ($y.a -replace '^\$f\d+, ', '') }
            if ($y.op -eq 'cvt.s.w') { return "int(" + (Src ($at - $k) $freg) + ")" }
            if ($y.op -eq 'mtc1') { return '?' }
            return $y.op + " " + $y.a
        }
        # mtc1 gpr -> freg
        for ($k = 1; $k -le 16 -and $at - $k -ge 0; $k++) {
            $y = $ins[$at - $k]
            if ($y.op -eq 'mtc1' -and $y.a -match ("^(\`$\w+), " + [regex]::Escape($freg) + "$")) { $g = $Matches[1]
                for ($q = 1; $q -le 16 -and $at - $k - $q -ge 0; $q++) { $w = $ins[$at - $k - $q]; if ($w.a -match ("^" + [regex]::Escape($g) + ", ")) { return "gpr " + $w.op + " " + ($w.a -replace ("^" + [regex]::Escape($g) + ", "), '') } }
                return "gpr ?" }
        }
        return '?'
    }
    $found = @()
    for ($i = 0; $i -lt $ins.Count; $i++) {
        if ($ins[$i].op -ne 'div.s' -or $ins[$i].a -notmatch '^(\$f\d+), (\$f\d+), (\$f\d+)$') { continue }
        $num = Src $i $Matches[2]; $den = Src $i $Matches[3]
        if ($num -match [regex]::Escape($off) + '\(' -or $den -match [regex]::Escape($off) + '\(') { $found += ("    div.s at 0x{0}: {1}  /  {2}" -f $ins[$i].pc, $num, $den) }
    }
    "0x{0} {1} ({2}): counter {3} {4} -> {5} division(s) in its function" -f $s.pc, $s.kind, (Split-Path $hit.Path -Leaf), $st.op, $st.a, $found.Count
    $found
}
