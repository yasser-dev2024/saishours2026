param(
    [string]$ApkPath = (Join-Path $PSScriptRoot "Sayes-Alkhayl-v2.1.1-universal.apk")
)

$ErrorActionPreference = "Stop"
$expectedPackage = "com.abuammar.sayesalkhayl.mobile2026"
$expectedVersionName = "2.1.1"
$expectedVersionCode = "22"
$expectedCertificate = "7b8c776e5db44ed433b9d92c7af5864dbc84978efc02f73bb0e09c05d1887ad0"
$requiredAbis = @("arm64-v8a", "armeabi-v7a", "x86_64")
$verificationDirectory = $null

if (-not (Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found: $ApkPath"
}

$ApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
$checksumPath = Join-Path $PSScriptRoot "SHA256SUMS.txt"
$apkName = [IO.Path]::GetFileName($ApkPath)
$checksumLine = Get-Content -LiteralPath $checksumPath |
    Where-Object { $_ -match ("\s+" + [regex]::Escape($apkName) + "$") } |
    Select-Object -First 1
if (-not $checksumLine) {
    throw "No SHA-256 entry exists for $apkName"
}
$expectedHash = ($checksumLine -split "\s+")[0].ToUpperInvariant()
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash.ToUpperInvariant()
if ($actualHash -ne $expectedHash) {
    throw "SHA-256 mismatch. Expected $expectedHash but found $actualHash"
}

try {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $verificationDirectory = Join-Path $tempRoot `
        ("sayes_alkhayl_verify_" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $verificationDirectory | Out-Null
    $verificationDirectory = (Resolve-Path -LiteralPath $verificationDirectory).Path
    if ($verificationDirectory -notmatch "^[\x00-\x7F]+$" -or
        -not $verificationDirectory.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The APK verification path must be ASCII and inside the temporary directory."
    }
    $toolApkPath = Join-Path $verificationDirectory "app.apk"
    Copy-Item -LiteralPath $ApkPath -Destination $toolApkPath
    $temporaryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $toolApkPath).Hash.ToUpperInvariant()
    if ($temporaryHash -ne $actualHash) {
        throw "The temporary APK copy does not match the published APK."
    }

    $sdkRoot = if ($env:ANDROID_HOME) {
        $env:ANDROID_HOME
    } elseif ($env:ANDROID_SDK_ROOT) {
        $env:ANDROID_SDK_ROOT
    } else {
        Join-Path $env:LOCALAPPDATA "Android\Sdk"
    }
    $buildToolsRoot = Join-Path $sdkRoot "build-tools"
    $buildTools = Get-ChildItem -Directory -LiteralPath $buildToolsRoot |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if ($null -eq $buildTools) {
        throw "Android build-tools were not found under $buildToolsRoot"
    }

    $aapt = Join-Path $buildTools.FullName "aapt.exe"
    $apksigner = Join-Path $buildTools.FullName "apksigner.bat"
    $zipalign = Join-Path $buildTools.FullName "zipalign.exe"
    foreach ($tool in @($aapt, $apksigner, $zipalign)) {
        if (-not (Test-Path -LiteralPath $tool)) {
            throw "Required Android verification tool is missing: $tool"
        }
    }

    $androidStudioJdk = Join-Path ${env:ProgramFiles} "Android\Android Studio1\jbr"
    if (Test-Path -LiteralPath (Join-Path $androidStudioJdk "bin\java.exe")) {
        $env:JAVA_HOME = $androidStudioJdk
    } elseif (-not $env:JAVA_HOME -or
        -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        throw "A working Java runtime was not found for apksigner."
    }

    $badging = (& $aapt dump badging $toolApkPath) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "aapt could not read the APK."
    }
    if ($badging -notmatch "package: name='$([regex]::Escape($expectedPackage))'") {
        throw "Unexpected package name."
    }
    if ($badging -notmatch "versionCode='$expectedVersionCode'") {
        throw "Unexpected versionCode."
    }
    if ($badging -notmatch "versionName='$([regex]::Escape($expectedVersionName))'") {
        throw "Unexpected versionName."
    }
    if ($badging -notmatch "(?m)^application-label:'.+'$") {
        throw "The application label is missing."
    }
    if ($badging -match "(?m)^application-debuggable") {
        throw "The APK is debuggable and must not be published."
    }
    foreach ($abi in $requiredAbis) {
        if ($badging -notmatch "'$([regex]::Escape($abi))'") {
            throw "Missing ABI: $abi"
        }
    }

    # aapt reports an ABI when any native helper exists. Require Flutter's
    # actual runtime and application libraries so the ABI is genuinely usable.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($toolApkPath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
        foreach ($abi in $requiredAbis) {
            foreach ($library in @("libapp.so", "libflutter.so")) {
                $requiredEntry = "lib/$abi/$library"
                if ($entryNames -notcontains $requiredEntry) {
                    throw "Missing runnable Flutter library: $requiredEntry"
                }
            }
        }
    } finally {
        $archive.Dispose()
    }

    $signature = (& $apksigner verify --verbose --print-certs $toolApkPath) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $signature -notmatch "(?m)^Verifies$") {
        throw "APK signature verification failed."
    }
    if ($signature -notmatch "Verified using v2 scheme \(APK Signature Scheme v2\): true") {
        throw "APK Signature Scheme v2 is missing."
    }
    if ($signature -notmatch [regex]::Escape($expectedCertificate)) {
        throw "The APK is signed by a different update certificate."
    }

    $manifest = (& $aapt dump xmltree $toolApkPath AndroidManifest.xml) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "AndroidManifest.xml could not be inspected."
    }
    if ($manifest -match "android:debuggable.*0xffffffff") {
        throw "The built manifest enables debugging."
    }
    if ($manifest -notmatch "android:allowBackup.*0x0") {
        throw "Android backups must be disabled for customer data."
    }
    if ($manifest -notmatch "android:usesCleartextTraffic.*0x0") {
        throw "Cleartext HTTP traffic must be disabled."
    }
    if ($manifest -notmatch [regex]::Escape("com.abuammar.horseclub.MainActivity")) {
        throw "The main full-screen alert activity is missing."
    }
    if ($manifest -notmatch "android:showWhenLocked.*0xffffffff") {
        throw "The alert activity must remain visible on the lock screen."
    }
    if ($manifest -notmatch "android:turnScreenOn.*0xffffffff") {
        throw "The alert activity must wake the screen."
    }

    $permissions = (& $aapt dump permissions $toolApkPath) -join "`n"
    foreach ($permission in @(
        "android.permission.CAMERA",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.USE_FULL_SCREEN_INTENT",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.WAKE_LOCK",
        "android.permission.VIBRATE"
    )) {
        if ($permissions -notmatch [regex]::Escape($permission)) {
            throw "Required application permission is missing: $permission"
        }
    }

    & $zipalign -c -P 16 4 $toolApkPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "APK zip alignment verification failed."
    }

    $size = (Get-Item -LiteralPath $ApkPath).Length
    if ($size -lt 10MB) {
        throw "APK size is unexpectedly small: $size bytes"
    }

    Write-Output "APK verification passed"
    Write-Output "Path: $ApkPath"
    Write-Output "Size: $size bytes"
    Write-Output "SHA-256: $actualHash"
    Write-Output "Package: $expectedPackage"
    Write-Output "Version: $expectedVersionName ($expectedVersionCode)"
    Write-Output "Certificate SHA-256: $expectedCertificate"
    Write-Output "Runnable ABIs: $($requiredAbis -join ', ')"
} finally {
    if ($verificationDirectory -and (Test-Path -LiteralPath $verificationDirectory)) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedVerificationDirectory =
            (Resolve-Path -LiteralPath $verificationDirectory).Path
        if ($resolvedVerificationDirectory.StartsWith(
                $tempRoot,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            [IO.Path]::GetFileName($resolvedVerificationDirectory) -like
                "sayes_alkhayl_verify_*") {
            Remove-Item -LiteralPath $resolvedVerificationDirectory -Recurse -Force
        } else {
            throw "Refusing to remove an unexpected verification directory."
        }
    }
}
