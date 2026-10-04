$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$stage = Join-Path $tempRoot ('WahaMatch3-PC-' + [guid]::NewGuid().ToString('N'))
$flutter = (Get-Command flutter -ErrorAction Stop).Source

function Invoke-Flutter {
    param([string[]]$Arguments)
    & $flutter @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter failed with exit code $LASTEXITCODE." }
}

try {
    Invoke-Flutter -Arguments @('create', '--platforms=web', '--project-name=waha_personal_pc', '--no-pub', $stage)
    $templateRoot = Join-Path $PSScriptRoot 'personal_pc'
    Copy-Item -LiteralPath (Join-Path $templateRoot 'lib/main.dart') -Destination (Join-Path $stage 'lib/main.dart') -Force
    $yamlPath = ($projectRoot.Replace('\', '/') | ConvertTo-Json -Compress)
    $pubspec = [System.IO.File]::ReadAllText((Join-Path $templateRoot 'pubspec.template.yaml'))
    $pubspec = $pubspec.Replace('__PROJECT_PATH_JSON__', $yamlPath)
    [System.IO.File]::WriteAllText((Join-Path $stage 'pubspec.yaml'), $pubspec, [System.Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Path (Join-Path $stage 'assets/audio') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/audio/background.mp3') -Destination (Join-Path $stage 'assets/audio/background.mp3')
    Copy-Item -LiteralPath (Join-Path $templateRoot 'assets/local_tiles') -Destination (Join-Path $stage 'assets/local_tiles') -Recurse
    $personalDirectory = Join-Path $projectRoot '.local/tiles'
    New-Item -ItemType Directory -Path $personalDirectory -Force | Out-Null
    $count = 0
    for ($tile = 0; $tile -lt 6; $tile++) {
        $source = Join-Path $personalDirectory "$tile.png"
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $stage "assets/local_tiles/$tile.png")
            $count++
        }
    }
    Write-Host "Personal PC mode: $count of 6 local images installed. Missing images use standard symbols."
    Write-Host 'Press q in the Flutter terminal to close the game.'
    Push-Location $stage
    try {
        Invoke-Flutter -Arguments @('pub', 'get')
        Invoke-Flutter -Arguments @('run', '-d', 'chrome', '--dart-define=PERSONAL_TILES=true')
    } finally { Pop-Location }
} finally {
    $resolvedStage = [System.IO.Path]::GetFullPath($stage)
    $resolvedParent = [System.IO.Path]::GetDirectoryName($resolvedStage).TrimEnd('\')
    if ($resolvedParent -ne $tempRoot.TrimEnd('\') -or
        [System.IO.Path]::GetFileName($resolvedStage) -notmatch '^WahaMatch3-PC-[a-f0-9]{32}$') {
        throw 'Refusing to clean an unexpected temporary path.'
    }
    if (Test-Path -LiteralPath $resolvedStage) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}

