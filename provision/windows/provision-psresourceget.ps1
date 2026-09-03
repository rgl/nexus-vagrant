# install PSResourceGet (previously known as PowerShellGet 3.x).
# see https://learn.microsoft.com/en-us/powershell/gallery/powershellget/install-powershellget?view=powershellget-3.x
# see https://github.com/PowerShell/PSResourceGet

# see https://www.powershellgallery.com/packages/Microsoft.PowerShell.PSResourceGet
# renovate: datasource=nuget:powershellgallery depName=Microsoft.PowerShell.PSResourceGet
$psResourceGetModuleVersion = '1.2.0'
Write-Host "Installing PSResourceGet $psResourceGetModuleVersion..."
Install-Module `
    -Repository PSGallery `
    -Name Microsoft.PowerShell.PSResourceGet `
    -RequiredVersion $psResourceGetModuleVersion `
    -Force
