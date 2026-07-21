Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

$proc = [W+EnumWindowsProc]{
param([IntPtr]$hWnd, [IntPtr]$lParam)
if ([W]::IsWindowVisible($hWnd)) {
[W]::ShowWindowAsync($hWnd, 3) | Out-Null   # 3 = maximize
}
$true
}

[W]::EnumWindows($proc, [IntPtr]::Zero) | Out-Null
