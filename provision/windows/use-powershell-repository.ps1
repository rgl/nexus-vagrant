param(
    [string]$nexusDomain = 'nexus.example.com'
)

# NB this is needed to answer 'Yes' to all PS related questions.
$ConfirmPreference = 'None'

Write-Host 'Default PowerShell sources:'
Get-PSRepository

Write-Host 'Configuring PowerShell to only use the nexus server...'
Get-PSRepository | Unregister-PSRepository
Install-PackageProvider NuGet -Force
Register-PSRepository `
    -Name nexus `
    -SourceLocation https://$nexusDomain/repository/powershell-group/ `
    -PublishLocation https://$nexusDomain/repository/powershell-hosted/ `
    -InstallationPolicy Trusted

Write-Host 'Current PowerShell sources:'
Get-PSRepository

Write-Host 'Installing the Sql Server module from the nexus server...'
Install-Module SqlServer

Write-Host 'Installing nuget and configuring PowerShellGet to use it...'
choco install -y nuget.commandline
$psGetNugetPath = 'C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe'
mkdir (Split-Path -Parent $psGetNugetPath) | Out-Null
New-Item `
    -ItemType SymbolicLink `
    -Path $psGetNugetPath `
    -Target 'C:\ProgramData\chocolatey\lib\NuGet.CommandLine\tools\NuGet.exe' `
    | Out-Null

Write-Host 'Publishing the ExampleGreeter module into the nexus server...'
Set-Location $env:TEMP
mkdir ExampleGreeter | Out-Null
Push-Location ExampleGreeter
Set-Content `
    -Encoding Ascii `
    ExampleGreeter.psm1 `
    @'
function Write-Greeting([string]$name) {
    "Hello $name!"
}
'@
New-ModuleManifest `
    ExampleGreeter.psd1 `
    -ModuleVersion '1.0.0' `
    -Author 'John Doe' `
    -Description 'The Classic Hello World' `
    -LicenseUri 'https://opensource.org/licenses/MIT' `
    -ProjectUri 'https://example.com/ExampleGreeter' `
    -RootModule 'ExampleGreeter.psm1' `
    -Tags `
        hello,
        example `
    -FunctionsToExport `
        Write-Greeting `
    -CmdletsToExport @() `
    -VariablesToExport @() `
    -AliasesToExport @()
Test-ModuleManifest ExampleGreeter.psd1
Publish-Module `
    -Path . `
    -Repository nexus `
    -NuGetApiKey (Get-Content c:\vagrant\shared\jenkins-nuget-api-key)
Pop-Location

Write-Host 'Installing and using the ExampleGreeter module...'
Install-Module ExampleGreeter
Import-Module ExampleGreeter
Get-Module ExampleGreeter | Format-List
Write-Greeting 'World'
