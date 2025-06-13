param(
    [string]$nexusDomain = 'nexus.example.com'
)

# install chocolatey.
Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Write-Host 'Default Chocolatey sources:'
choco sources list

# see https://github.com/chocolatey/choco/wiki/CommandsSources
Write-Host 'Configuring chocolatey to use the nexus server...'
choco sources remove --name chocolatey
choco sources add --name nexus --source https://$nexusDomain/repository/chocolatey-group/

Write-Host 'Current Chocolatey sources:'
choco sources list

$browser = 'firefox'

if ($browser -eq 'firefox') {
  Write-Host 'Installing Firefox from the nexus server...'
  choco install -y firefox --params 'l=en-US'
  choco install -y SetDefaultBrowser
  SetDefaultBrowser @((SetDefaultBrowser | Where-Object {$_ -like 'HKLM Firefox-*'}) -split ' ')
} else {
  Write-Host 'Installing Google Chrome from the nexus server...'
  # NB --ignore-checksums is needed because chrome does not release a versioned
  #    installer... as such, sometimes this package installation breaks if we
  #    do not ignore the checksums and there's a new chrome version available.
  # see https://www.chromium.org/administrators/configuring-other-preferences
  choco install -y --ignore-checksums googlechrome
  $chromeLocation = 'C:\Program Files\Google\Chrome\Application'
  cp -Force GoogleChrome-external_extensions.json (Resolve-Path "$chromeLocation\*\default_apps\external_extensions.json")
  cp -Force GoogleChrome-master_preferences.json "$chromeLocation\master_preferences"
  cp -Force GoogleChrome-master_bookmarks.html "$chromeLocation\master_bookmarks.html"
  choco install -y SetDefaultBrowser
  SetDefaultBrowser HKLM "Google Chrome"
}

# see https://github.com/chocolatey/choco/wiki/CreatePackages
# see https://docs.nuget.org/docs/reference/nuspec-reference
Write-Host 'Creating the graceful-terminating-console-application-windows chocolatey package...'
Push-Location $env:TEMP
mkdir graceful-terminating-console-application-windows | Out-Null
Set-Location graceful-terminating-console-application-windows
Set-Content -Encoding Ascii graceful-terminating-console-application-windows.nuspec @'
<package>
  <metadata>
    <id>graceful-terminating-console-application-windows</id>
    <version>0.5.0</version>
    <authors>Rui Lopes</authors>
    <owners>Rui Lopes</owners>
    <licenseUrl>http://choosealicense.com/licenses/mit/</licenseUrl>
    <projectUrl>https://github.com/rgl/graceful-terminating-console-application-windows</projectUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>a graceful terminating console application for windows</description>
    <releaseNotes>Release Notes Go Here</releaseNotes>
    <copyright>Copyright Rui Lopes</copyright>
    <tags>graceful console terminate exit</tags>
  </metadata>
</package>
'@
mkdir tools | Out-Null
(New-Object Net.WebClient).DownloadFile(
    'https://github.com/rgl/graceful-terminating-console-application-windows/releases/download/v0.5.0/graceful-terminating-console-application-windows.zip',
    "$env:TEMP\graceful-terminating-console-application-windows.zip")
Expand-Archive "$env:TEMP\graceful-terminating-console-application-windows.zip" tools
choco pack
Write-Host 'Publishing the graceful-terminating-console-application-windows chocolatey package...'
choco push `
    --source https://$nexusDomain/repository/chocolatey-hosted/ `
    --api-key (Get-Content c:\vagrant\shared\jenkins-nuget-api-key)
Pop-Location

Write-Host 'Installing the graceful-terminating-console-application-windows chocolatey package...'
choco install -y graceful-terminating-console-application-windows
Write-Host 'graceful-terminating-console-application-windows installed at:'
Get-ChildItem C:\ProgramData\chocolatey\bin\graceful-terminating-console-application-windows.exe
