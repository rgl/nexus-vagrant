param(
    [string]$nexusDomain = 'nexus.example.com'
)

# NB this is needed to answer 'Yes' to all PS related questions.
$ConfirmPreference = 'None'

Write-Host 'Default PowerShell sources:'
Get-PSRepository

Write-Host "Unregistering the default PowerShell sources..."
Get-PSRepository | Unregister-PSRepository

Write-Host 'Configuring PowerShell to use the nexus server...'
Register-PSRepository `
    -Name nexus `
    -SourceLocation https://$nexusDomain/repository/powershell-group/ `
    -PublishLocation https://$nexusDomain/repository/powershell-hosted/ `
    -InstallationPolicy Trusted

Write-Host 'Current PowerShell sources:'
Get-PSRepository

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

Write-Host 'Installing the ExampleGreeter module...'
Install-Module ExampleGreeter
Get-Module ExampleGreeter -ListAvailable | Format-List

Write-Host 'Using the ExampleGreeter module...'
Import-Module ExampleGreeter
Write-Greeting 'World'

Write-Host 'Uninstalling the ExampleGreeter module...'
Uninstall-Module ExampleGreeter
