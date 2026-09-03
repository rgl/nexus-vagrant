param(
    [string]$nexusDomain = 'nexus.example.com'
)

Write-Host 'Default PSResourceGet repositories:'
Get-PSResourceRepository

Write-Host "Unregistering the default PSResourceGet sources..."
Get-PSResourceRepository | Unregister-PSResourceRepository

Write-Host 'Configuring PSResourceGet to only use the nexus server...'
Register-PSResourceRepository `
    -Name nexus `
    -Uri https://$nexusDomain/repository/powershell-hosted/index.json `
    -ApiVersion V3 `
    -Trusted

Write-Host 'Current PSResourceGet repositories:'
Get-PSResourceRepository

Write-Host 'Publishing the ExampleGreeter module into the nexus server...'
Set-Location $env:TEMP
mkdir ExamplePSResourceGreeter | Out-Null
Push-Location ExamplePSResourceGreeter
Set-Content `
    -Encoding Ascii `
    ExamplePSResourceGreeter.psm1 `
    @'
function Write-ExamplePSResourceGreeting([string]$name) {
    "Hello $name!"
}
'@
New-ModuleManifest `
    ExamplePSResourceGreeter.psd1 `
    -ModuleVersion '1.0.0' `
    -Author 'John Doe' `
    -Description 'The Classic Hello World' `
    -LicenseUri 'https://opensource.org/licenses/MIT' `
    -ProjectUri 'https://example.com/ExamplePSResourceGreeter' `
    -RootModule 'ExamplePSResourceGreeter.psm1' `
    -Tags `
        hello,
        example `
    -FunctionsToExport `
        Write-ExamplePSResourceGreeting `
    -CmdletsToExport @() `
    -VariablesToExport @() `
    -AliasesToExport @()
Test-ModuleManifest ExamplePSResourceGreeter.psd1
Publish-PSResource `
    -Repository nexus `
    -ApiKey (Get-Content c:\vagrant\shared\jenkins-nuget-api-key) `
    -Path .
Pop-Location

Write-Host 'Installing and using the ExamplePSResourceGreeter module...'
Install-PSResource ExamplePSResourceGreeter
Get-PSResource ExamplePSResourceGreeter | Format-List
Get-Module ExamplePSResourceGreeter -ListAvailable | Format-List

Write-Host 'Using the ExamplePSResourceGreeter module...'
Import-Module ExamplePSResourceGreeter
Write-ExamplePSResourceGreeting 'World'

Write-Host 'Uninstalling the ExamplePSResourceGreeter module...'
Uninstall-PSResource ExamplePSResourceGreeter
