# Prueba del interruptor "Peleas a 60 fps" del menu del host sin tocar el teclado: escribe fps60Request (1 = 30, 2 = 60)
# en la cabecera del ring del juego en marcha, como hace el menu, y lee gameFps60.
#   .\fps60_ring_test.ps1 -Want 2
param([int]$Want = 0)
if (-not ("Dbz.Ring" -as [type])) {
    Add-Type -Namespace Dbz -Name Ring -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern System.IntPtr OpenFileMappingW(uint access, bool inherit, string name);
[DllImport("kernel32.dll", SetLastError = true)] public static extern System.IntPtr MapViewOfFile(System.IntPtr h, uint access, uint hi, uint lo, System.UIntPtr bytes);
[DllImport("kernel32.dll")] public static extern bool UnmapViewOfFile(System.IntPtr p);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(System.IntPtr h);
'@
}
$game = Get-Process ps2EntryRunner -ErrorAction Stop | Select-Object -First 1
$h = [Dbz.Ring]::OpenFileMappingW(0x6, $false, "Local\PS2RecompGsLiveRing_$($game.Id)")
if ($h -eq [IntPtr]::Zero) { throw "no ring for pid $($game.Id)" }
$p = [Dbz.Ring]::MapViewOfFile($h, 0x6, 0, 0, [UIntPtr]::new(192))
# RingHeader: gameFps60 at byte 172, fps60Request at 176 (see ps2_live_ring.h)
if ($Want -in 1, 2) { [Runtime.InteropServices.Marshal]::WriteInt32($p, 176, $Want) }
Start-Sleep -Milliseconds 500
"gameFps60={0} fps60Request={1}" -f [Runtime.InteropServices.Marshal]::ReadInt32($p, 172), [Runtime.InteropServices.Marshal]::ReadInt32($p, 176)
[void][Dbz.Ring]::UnmapViewOfFile($p); [void][Dbz.Ring]::CloseHandle($h)
