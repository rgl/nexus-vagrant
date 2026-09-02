# install PowerShellGet v2.
# NB we cannot uninstall the built-in modules.
# see https://learn.microsoft.com/en-us/powershell/gallery/powershellget/install-powershellget?view=powershellget-2.x

$nugetPackageProviderVersion = '2.8.5.208'
Write-Host "Installing the NuGet $nugetPackageProviderVersion provider..."
Install-PackageProvider `
    -Name NuGet `
    -RequiredVersion $nugetPackageProviderVersion `
    -Force `
    | Format-List

# see https://community.chocolatey.org/packages/nuget.commandline
# renovate: datasource=nuget:chocolatey depName=nuget.commandline
$nugetVersion = '7.9.0'
Write-Host "Installing nuget $nugetVersion and configuring PowerShellGet to use it..."
choco install -y nuget.commandline --version $nugetVersion
$psGetNugetPath = 'C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe'
mkdir (Split-Path -Parent $psGetNugetPath) | Out-Null
New-Item `
    -ItemType SymbolicLink `
    -Path $psGetNugetPath `
    -Target 'C:\ProgramData\chocolatey\lib\NuGet.CommandLine\tools\NuGet.exe' `
    | Out-Null

# see https://www.powershellgallery.com/packages/PowerShellGet
# renovate: datasource=nuget:powershellgallery depName=PowerShellGet
$powerShellGetModuleVersion = '2.2.5'
Write-Host "Installing PowerShellGet $powerShellGetModuleVersion..."
Install-Module `
    -Repository PSGallery `
    -Name PowerShellGet `
    -RequiredVersion $powerShellGetModuleVersion `
    -AllowClobber `
    -Force
