# Regenera los parches propios de Windows:
#  patches\bt3recomp-bt4mod-windows.patch  sobre BT3-Recomp e22a34b + dbz-bt4-recomp\patches\bt3recomp-bt4mod-full.patch
#  patches\pcsx2-gsrunner-dbz-windows.patch sobre el arbol PCSX2 de NBA + dbz-bt4-recomp\patches\pcsx2-gsrunner-live-dbz.patch
$g = "C:\NBAStreetRecomp\tools\mingit\cmd\git.exe"
$R = "C:\DBZBT4Recomp"
New-Item -ItemType Directory -Force "$R\patches" | Out-Null

function Write-Diff($baseRoot, $newRoot, [string[]]$files, $outFile) {
    $out = foreach ($rel in $files) { & $g diff --no-index "$baseRoot/$rel" "$newRoot/$rel" }
    $txt = ($out -join "`n").Replace("a/$baseRoot/", 'a/').Replace("b/$newRoot/", 'b/')
    [IO.File]::WriteAllText($outFile, $txt + "`n")
}

# 1. Runtime (BT3-Recomp)
$base = "$R\tmp_base"
& $g -C "$R\bt3mod" worktree prune
& $g -C "$R\bt3mod" worktree add --detach $base e22a34b | Out-Null
& $g -C $base apply --whitespace=nowarn --exclude=ps2xRuntime/third_party/parallel-gs "$R\dbz-bt4-recomp\patches\bt3recomp-bt4mod-full.patch"
if ($LASTEXITCODE -ne 0) { throw "no aplica bt3recomp-bt4mod-full.patch" }
$rt = @('ps2xRuntime/src/lib/ps2_gs_live.cpp', 'ps2xRuntime/src/lib/ps2_live_ring.h', 'ps2xRuntime/src/lib/game_overrides.cpp',
        'ps2xRuntime/src/lib/Kernel/Stubs/Helpers/Support.h', 'ps2xRuntime/src/lib/ps2_host_audio.cpp',
        'games/bt3/fps60_sites.txt', 'ps2xRuntime/src/lib/ps2_stepcensus.cpp',
        # online: the relay client and netwait, and the pad that only counts while the game is in front
        'ps2xRuntime/src/lib/ps2_netplay.cpp', 'ps2xRuntime/src/lib/pad_config.cpp', 'ps2xRuntime/include/runtime/ps2_gs_live.h',
        # deterministic online boot: wait before the first instruction, per-match clock, shared memory card
        'ps2xRuntime/include/runtime/ps2_netplay.h', 'ps2xRuntime/src/lib/ps2_runtime.cpp', 'ps2xRuntime/src/lib/Kernel/Stubs/CD.cpp')
Write-Diff 'C:/DBZBT4Recomp/tmp_base' 'C:/DBZBT4Recomp/bt3mod' $rt "$R\patches\bt3recomp-bt4mod-windows.patch"
& $g -C $base apply --check "$R\patches\bt3recomp-bt4mod-windows.patch"
$ok1 = $LASTEXITCODE -eq 0
& $g -C "$R\bt3mod" worktree remove --force $base

# 2. Host (PCSX2): los archivos de la NBA con el parche DBZ aplicado, contra los de C:\DBZBT4Recomp\pcsx2
$hb = "$R\tmp_host"
$hf = @('pcsx2/GSDumpReplayer.cpp', 'pcsx2/GSDumpReplayer.h', 'pcsx2/Ps2LiveRing.h', 'pcsx2-gsrunner/Main.cpp')
Remove-Item -Recurse -Force $hb -ErrorAction SilentlyContinue
foreach ($rel in $hf) { $d = Join-Path $hb $rel; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null; Copy-Item "C:\NBAStreetRecomp\pcsx2\$rel" $d }
& $g -C $hb init -q
& $g -C $hb apply --include=pcsx2/GSDumpReplayer.cpp --include=pcsx2/Ps2LiveRing.h --include=pcsx2-gsrunner/Main.cpp "$R\dbz-bt4-recomp\patches\pcsx2-gsrunner-live-dbz.patch"
if ($LASTEXITCODE -ne 0) { throw "no aplica pcsx2-gsrunner-live-dbz.patch sobre la NBA" }
Write-Diff 'C:/DBZBT4Recomp/tmp_host' 'C:/DBZBT4Recomp/pcsx2' $hf "$R\patches\pcsx2-gsrunner-dbz-windows.patch"
& $g -C $hb apply --check "$R\patches\pcsx2-gsrunner-dbz-windows.patch"
$ok2 = $LASTEXITCODE -eq 0
Remove-Item -Recurse -Force $hb

if ($ok1 -and $ok2) { "OK: patches\bt3recomp-bt4mod-windows.patch, patches\pcsx2-gsrunner-dbz-windows.patch" } else { throw "algun parche generado no aplica ($ok1 / $ok2)" }
