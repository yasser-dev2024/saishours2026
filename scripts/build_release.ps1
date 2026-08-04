$ErrorActionPreference = 'Stop'

$signingRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.horseclub-signing'
$keystorePath = Join-Path $signingRoot 'sayes-alkhayl-release.jks'
$passwordPath = Join-Path $signingRoot 'release-password.clixml'

if (-not (Test-Path -LiteralPath $keystorePath) -or -not (Test-Path -LiteralPath $passwordPath)) {
    throw 'Horse Club release signing files are missing from the secure external folder.'
}

$securePassword = Import-Clixml -LiteralPath $passwordPath
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $env:HORSECLUB_STORE_FILE = $keystorePath
    $env:HORSECLUB_STORE_PASSWORD = $plainPassword
    $env:HORSECLUB_KEY_ALIAS = 'sayesalkhayl'
    $env:HORSECLUB_KEY_PASSWORD = $plainPassword
    # Keep one installable APK for 32-bit and 64-bit ARM phones/tablets.
    flutter build apk --release --target-platform android-arm,android-arm64
    if ($LASTEXITCODE -ne 0) {
        throw "Release build failed with exit code $LASTEXITCODE"
    }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    Remove-Item Env:HORSECLUB_STORE_FILE -ErrorAction SilentlyContinue
    Remove-Item Env:HORSECLUB_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:HORSECLUB_KEY_ALIAS -ErrorAction SilentlyContinue
    Remove-Item Env:HORSECLUB_KEY_PASSWORD -ErrorAction SilentlyContinue
}
