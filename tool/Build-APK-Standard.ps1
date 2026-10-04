$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$flutter = (Get-Command flutter -ErrorAction Stop).Source

function Invoke-Flutter {
    param([string[]]$Arguments)
    & $flutter @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter failed with exit code $LASTEXITCODE." }
}

Push-Location $projectRoot
try {
    Invoke-Flutter -Arguments @('pub', 'get')
    Invoke-Flutter -Arguments @('test')
    Invoke-Flutter -Arguments @('build', 'apk', '--release', '--dart-define=PERSONAL_TILES=false')
    $apk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
    & (Join-Path $PSScriptRoot 'Check-APK-Assets.ps1') -ApkPath $apk
    Write-Host "Standard APK: $apk"
} finally { Pop-Location }

