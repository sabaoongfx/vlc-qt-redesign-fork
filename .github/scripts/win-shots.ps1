# Launches the portable Windows build on the runner's desktop and takes screenshots.
# usage: win-shots.ps1 <folder with vlc.exe> <output folder>
param([string]$Vlc, [string]$Out)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $Out | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Native {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][Native]::SetProcessDPIAware()

function Shot($name) {
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $bmp.Save("$Out\$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "shot $name"
}

function Click($x, $y) {
    [void][Native]::SetCursorPos([int]$x, [int]$y)
    Start-Sleep -Milliseconds 150
    [Native]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    [Native]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}

# click a UI Automation element by name; returns false if it was not found
function ClickByName($name) {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), $name
    $el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
    if (-not $el) { Write-Host "not found: $name"; return $false }
    $r = $el.Current.BoundingRectangle
    Click ($r.X + $r.Width / 2) ($r.Y + $r.Height / 2)
    return $true
}

function DumpNames($file) {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $lines = foreach ($e in $all) { "{0} | {1} | {2}" -f $e.Current.ControlType.ProgrammaticName, $e.Current.Name, $e.Current.BoundingRectangle }
    $lines | Select-Object -First 400 | Set-Content "$Out\$file"
}

$exe = Join-Path $Vlc 'vlc.exe'
$conf = Join-Path $env:APPDATA 'vlc'
New-Item -ItemType Directory -Force $conf | Out-Null

foreach ($scheme in @(@('system', 0), @('day', 1), @('night', 2))) {
    $tag = $scheme[0]
    Get-Process vlc -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    # a fresh config each time: no "restore the playlist after a crash" prompt, and the scheme comes from here
    Remove-Item -Recurse -Force $conf -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $conf | Out-Null
    foreach ($name in @('vlc-qt-interface.ini', 'vlc-qt-interface.conf')) {
        Set-Content "$conf\$name" "[MainWindow]`ncolor-scheme-index=$($scheme[1])`n"
    }

    $p = Start-Process $exe -ArgumentList '--no-qt-privacy-ask', '--no-media-library', '--verbose=1', '--file-logging', "--logfile=$Out\vlc-$tag.log" -PassThru
    Start-Sleep -Seconds 12
    Shot "$tag-main"

    # Preferences (Ctrl+P) and each category
    [System.Windows.Forms.SendKeys]::SendWait('^p')
    Start-Sleep -Seconds 4
    Shot "$tag-prefs"
    if ($tag -eq 'system') { DumpNames 'ui-names.txt' }
    foreach ($tab in @('Audio', 'Video', 'Subtitles / OSD', 'Input / Codecs', 'Hotkeys', 'Media Library')) {
        if (ClickByName $tab) {
            Start-Sleep -Seconds 2
            Shot ("$tag-prefs-" + ($tab -replace '[^A-Za-z]', ''))
        }
    }
    [void](ClickByName 'All')
    Start-Sleep -Seconds 3
    Shot "$tag-prefs-all"

    Get-Process vlc -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    Remove-Item -Recurse -Force $conf -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $conf | Out-Null
    foreach ($name in @('vlc-qt-interface.ini', 'vlc-qt-interface.conf')) {
        Set-Content "$conf\$name" "[MainWindow]`ncolor-scheme-index=$($scheme[1])`n"
    }
    # player: capture the desktop as a video source so the player UI has something to show
    $p = Start-Process $exe -ArgumentList '--no-qt-privacy-ask', '--no-media-library', 'screen://' -PassThru
    Start-Sleep -Seconds 12
    # the controls auto-hide over video: wake them up by moving the mouse
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    foreach ($dy in 40, 80, 120) { [void][Native]::SetCursorPos([int]($b.Width / 2), [int]($b.Height - $dy)); Start-Sleep -Milliseconds 400 }
    Start-Sleep -Seconds 1
    Shot "$tag-player"
    Get-Process vlc -ErrorAction SilentlyContinue | Stop-Process -Force
}
