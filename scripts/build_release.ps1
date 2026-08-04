param(
    [string]$OutputName = "Sayes-Alkhayl-v2.1.1-universal.apk"
)

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "..\tools\build_android_apk.ps1") -OutputName $OutputName
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
