# dump all the windows trusted roots into a ca file.
$pems = New-Object System.Text.StringBuilder
Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
    # $_ is-a System.Security.Cryptography.X509Certificates.X509Certificate2
    Write-Host "Exporting the $($_.Issuer) certificate..."
    [void]$pems.AppendLine('-----BEGIN CERTIFICATE-----')
    [void]$pems.AppendLine(
        [Convert]::ToBase64String(
            $_.Export('Cert'),
            'InsertLineBreaks'));
    [void]$pems.AppendLine("-----END CERTIFICATE-----");
}
Set-Content `
    -Encoding Ascii `
    C:\ProgramData\ca-certificates.crt `
    $pems.ToString()
