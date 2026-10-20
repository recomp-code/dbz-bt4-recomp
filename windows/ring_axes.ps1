# Escribe los ejes del mando que el host publica al juego (RingHeader.padAxes, byte 144: lx | ly<<8 | rx<<16 | ry<<24,
# 0x80 = centro) en el juego en marcha. Para pruebas de menus que usan los sticks.   .\ring_axes.ps1 -Axes 0x80008080
param([string]$Axes = "0x80808080")
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
[Runtime.InteropServices.Marshal]::WriteInt32($p, 144, [BitConverter]::ToInt32([BitConverter]::GetBytes([Convert]::ToUInt32($Axes, 16)), 0))
[void][Dbz.Ring]::UnmapViewOfFile($p); [void][Dbz.Ring]::CloseHandle($h)
