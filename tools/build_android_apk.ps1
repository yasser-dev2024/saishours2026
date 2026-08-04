param(
    [string]$OutputName = "Sayes-Alkhayl-v2.1.1-universal.apk"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$releaseDirectory = Join-Path $projectRoot "releases"
$signingRoot = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".horseclub-signing"
$keystorePath = Join-Path $signingRoot "sayes-alkhayl-release.jks"
$passwordPath = Join-Path $signingRoot "release-password.clixml"
$stage = $null
$passwordPointer = [IntPtr]::Zero

function Invoke-FlutterStep {
    param([Parameter(Mandatory)][string[]]$Arguments)

    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function New-AsciiBuildStage {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $candidate = Join-Path $tempRoot ("sayes_alkhayl_android_" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $candidate | Out-Null
    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    if ($resolved -notmatch "^[\x00-\x7F]+$" -or
        -not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The Android staging path must be ASCII and inside the temporary directory: $resolved"
    }
    return $resolved
}

if ([IO.Path]::GetExtension($OutputName) -ne ".apk" -or
    [IO.Path]::GetFileName($OutputName) -ne $OutputName) {
    throw "OutputName must be a plain APK file name."
}
if (-not (Test-Path -LiteralPath $keystorePath) -or
    -not (Test-Path -LiteralPath $passwordPath)) {
    throw "Sayes Alkhayl release signing files are missing from the protected external folder."
}

if (-not (Test-Path -LiteralPath $releaseDirectory)) {
    New-Item -ItemType Directory -Path $releaseDirectory | Out-Null
}

$stage = New-AsciiBuildStage
try {
    robocopy $projectRoot $stage /E /XD .git .dart_tool .idea build dist node_modules releases device_tests | Out-Null
    if ($LASTEXITCODE -gt 7) {
        throw "Failed to copy the project to the ASCII staging directory. Robocopy exit code: $LASTEXITCODE"
    }

    $securePassword = Import-Clixml -LiteralPath $passwordPath
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $env:HORSECLUB_STORE_FILE = $keystorePath
    $env:HORSECLUB_STORE_PASSWORD = $plainPassword
    $env:HORSECLUB_KEY_ALIAS = "sayesalkhayl"
    $env:HORSECLUB_KEY_PASSWORD = $plainPassword

    Push-Location $stage
    try {
        Invoke-FlutterStep @("clean")
        Invoke-FlutterStep @("pub", "get")
        Invoke-FlutterStep @("analyze")
        Invoke-FlutterStep @("test")
        # Flutter release supports ARM32, ARM64 and x86_64 in one universal APK.
        # Do not use --split-per-abi.
        Invoke-FlutterStep @("build", "apk", "--release")
    } finally {
        Pop-Location -ErrorAction SilentlyContinue
    }

    $sourceApk = Join-Path $stage "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path -LiteralPath $sourceApk)) {
        throw "Android APK was not created at $sourceApk"
    }

    $outputPath = Join-Path $releaseDirectory $OutputName
    Copy-Item -LiteralPath $sourceApk -Destination $outputPath -Force
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash.ToUpperInvariant()
    Set-Content -LiteralPath (Join-Path $releaseDirectory "SHA256SUMS.txt") `
        -Value "$hash  $OutputName" -Encoding ASCII

    & (Join-Path $releaseDirectory "verify-apk.ps1") -ApkPath $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "APK verification failed with exit code $LASTEXITCODE"
    }
    Write-Output "Universal Android APK ready: $outputPath"
} finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    Remove-Item Env:HORSECLUB_STORE_FILE -ErrorAction SilentlyContinue
    Remove-Item Env:HORSECLUB_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:HORSECLUB_KEY_ALIAS -ErrorAction SilentlyContinue
    Remove-Item Env:HORSECLUB_KEY_PASSWORD -ErrorAction SilentlyContinue
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedStage = (Resolve-Path -LiteralPath $stage).Path
        if ($resolvedStage.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            [IO.Path]::GetFileName($resolvedStage) -like "sayes_alkhayl_android_*") {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        } else {
            throw "Refusing to remove an unexpected staging directory: $resolvedStage"
        }
    }
}
