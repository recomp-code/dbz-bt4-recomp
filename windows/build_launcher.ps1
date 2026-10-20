# Compila el launcher DBZ_BT4.exe con el csc de .NET Framework 4 (incluido en Windows; no hace falta Visual Studio).
param([string]$Out = "C:\DBZBT4Recomp\dist\DBZ_BT4.exe")
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$src = "C:\DBZBT4Recomp\windows_launcher\DBZ_BT4.cs"
$icon = "C:\DBZBT4Recomp\bt3mod\build\ps2xRuntime\assets\bt3.ico"
& $csc /nologo /target:winexe /optimize+ /platform:anycpu "/win32icon:$icon" "/out:$Out" `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll $src
if ($LASTEXITCODE -ne 0) { throw "csc fallo ($LASTEXITCODE)" }
Get-Item $Out | Select-Object Length, FullName
