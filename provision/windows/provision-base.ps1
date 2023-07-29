param(
    [string]$nexusDomain = 'nexus.example.com'
)

# set keyboard layout.
# NB you can get the name from the list:
#      [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures') | out-gridview
Set-WinUserLanguageList pt-PT -Force

# set the date format, number format, etc.
Set-Culture pt-PT

# set the timezone.
# tzutil /l lists all available timezone ids
& $env:windir\system32\tzutil /s "GMT Standard Time"

# show window content while dragging.
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name DragFullWindows -Value 1

# set the desktop wallpaper.
Add-Type -AssemblyName System.Drawing
$backgroundColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$backgroundPath = 'C:\Windows\Web\Wallpaper\Windows\sonatype-nexus-repository.png'
$logo = [System.Drawing.Image]::FromFile((Resolve-Path 'sonatype-nexus-repository.png'))
$b = New-Object System.Drawing.Bitmap($logo.Width, $logo.Height)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear($backgroundColor)
$g.DrawImage($logo, 0, 0, $logo.Width, $logo.Height)
$b.Save($backgroundPath)
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name Wallpaper -Value $backgroundPath
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name WallpaperStyle -Value 0
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name TileWallpaper -Value 0
Set-ItemProperty -Path 'HKCU:Control Panel\Colors' -Name Background -Value ($backgroundColor.R,$backgroundColor.G,$backgroundColor.B -join ' ')
Add-Type @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;

public static class WindowsWallpaper
{
    private const int COLOR_DESKTOP = 0x01;

    [DllImport("user32", SetLastError=true)]
    private static extern bool SetSysColors(int cElements, int[] lpaElements, int[] lpaRgbValues);

    private const uint SPI_SETDESKWALLPAPER = 0x14;
    private const uint SPIF_UPDATEINIFILE = 0x01;
    private const uint SPIF_SENDWININICHANGE = 0x02;

    [DllImport("user32", SetLastError=true)]
    private static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);

    public static void Set(Color color, string path)
    {
        var elements = new int[] { COLOR_DESKTOP };
        var colors = new int[] { ColorTranslator.ToWin32(color) };
        SetSysColors(elements.Length, elements, colors);
        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, path, SPIF_SENDWININICHANGE);
    }
}
'@ -ReferencedAssemblies System.Drawing
[WindowsWallpaper]::Set($backgroundColor, $backgroundPath)

# cleanup the taskbar by removing the existing buttons and unpinning all applications; once the user logs on.
# NB the shell executes these RunOnce commands about ~10s after the user logs on.
$configureDesktopScript = @'
# unpin all applications from the taskbar.
# NB this can only be done in a logged on session.
$pinnedTaskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
(New-Object -Com Shell.Application).NameSpace($pinnedTaskbarPath).Items() `
    | ForEach-Object {
        $unpinVerb = $_.Verbs() | Where-Object { $_.Name -eq 'Unpin from tas&kbar' }
        if ($unpinVerb) {
            $unpinVerb.DoIt()
        } else {
            $shortcut = (New-Object -Com WScript.Shell).CreateShortcut($_.Path)
            if (!$shortcut.TargetPath -and ($shortcut.IconLocation -eq '%windir%\explorer.exe,0')) {
                Remove-Item -Force $_.Path
            }
        }
    }
Get-Item HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband `
    | Set-ItemProperty -Name Favorites -Value 0xff `
    | Set-ItemProperty -Name FavoritesResolve -Value 0xff `
    | Set-ItemProperty -Name FavoritesVersion -Value 3 `
    | Set-ItemProperty -Name FavoritesChanges -Value 1 `
    | Set-ItemProperty -Name FavoritesRemovedChanges -Value 1

# hide the search button.
Set-ItemProperty -Path HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0

# hide the task view button.
Set-ItemProperty -Path HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -Value 0

# never combine the taskbar buttons.
# possibe values:
#   0: always combine and hide labels (default)
#   1: combine when taskbar is full
#   2: never combine
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 2

# remove default or uneeded files.
@(
    "$env:USERPROFILE\Desktop\desktop.ini"
    "$env:USERPROFILE\Desktop\*.lnk"
    "$env:USERPROFILE\Desktop\*.url"
    "$env:PUBLIC\Desktop\desktop.ini"
    "$env:PUBLIC\Desktop\*.lnk"
    "$env:PUBLIC\Desktop\*.url"
) | Remove-Item -Force

# add desktop shortcuts.
@(
    ,('Nexus',                 'https://@@NEXUS_DOMAIN@@')
) | ForEach-Object {
    if ($_[1] -like 'http*') {
        [IO.File]::WriteAllText("$env:USERPROFILE\Desktop\$($_[0]).url", @"
[InternetShortcut]
URL=$($_[1])
"@)
    } elseif (!(Test-Path $_[1])) {
        return
    } elseif ($_[1] -like '*.lnk') {
        Copy-Item $_[1] "$env:USERPROFILE\Desktop\$($_[0]).lnk"
    } else {
        $extraArguments = @{
            IconLocation = $_[1]
        }
        if ($_.Length -gt 2) {
            $extraArguments.Arguments = $_[2]
            $extraArguments.IconLocation = $_[3]
            $extraArguments.WorkingDirectory = $_[4]
        }
        # add into the Desktop.
        Install-ChocolateyShortcut `
            -ShortcutFilePath "$env:USERPROFILE\Desktop\$($_[0]).lnk" `
            -TargetPath $_[1] `
            @extraArguments
        # add into the Start Menu.
        Copy-Item `
            "$env:USERPROFILE\Desktop\$($_[0]).lnk" `
            "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs"
    }
}

# restart explorer to apply the changed settings.
(Get-Process explorer).Kill()
'@ -replace '@@NEXUS_DOMAIN@@',$nexusDomain
[IO.File]::WriteAllText("$env:USERPROFILE\ConfigureDesktop.ps1", $configureDesktopScript)
New-Item -Path HKCU:Software\Microsoft\Windows\CurrentVersion\RunOnce -Force `
    | New-ItemProperty -Name ConfigureDesktop -Value 'PowerShell -WindowStyle Hidden -File "%USERPROFILE%\ConfigureDesktop.ps1"' -PropertyType ExpandString `
    | Out-Null

# show hidden files.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1

# show file extensions.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0

# display full path in the title bar.
New-Item -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState -Force `
    | New-ItemProperty -Name FullPath -Value 1 -PropertyType DWORD `
    | Out-Null

# set default Explorer location to This PC.
Set-ItemProperty -Path HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Value 1

# trust the nexus server certificate.
Import-Certificate `
    -FilePath "c:/vagrant/shared/$nexusDomain-crt.der" `
    -CertStoreLocation Cert:\LocalMachine\Root `
    | Out-Null
