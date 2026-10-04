param([Parameter(Mandatory = $true)][string]$ApkPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead([System.IO.Path]::GetFullPath($ApkPath))
try {
    $unexpected = @($archive.Entries | Where-Object {
        $_.FullName -match '(^|/)(local_tiles|\.local|personal_pc)(/|$)' -or
        ($_.FullName -like 'assets/flutter_assets/*' -and
            $_.FullName -match '\.(png|jpe?g|svg|webp|gif|bmp|avif)$')
    })
    if ($unexpected.Count -gt 0) {
        throw ('Unexpected image assets in the standard APK: ' + (($unexpected | ForEach-Object FullName) -join ', '))
    }
    Write-Host 'APK asset check passed: no personal directories or image assets in the Flutter bundle.'
} finally { $archive.Dispose() }

