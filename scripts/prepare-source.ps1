param(
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not [IO.Path]::IsPathRooted($Output)) {
    throw 'Output must be an absolute archive path.'
}
$archivePath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $archivePath) {
    throw "Preserving existing archive: $archivePath. Choose a new output path."
}
if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($archivePath)) -PathType Container)) {
    throw 'The output parent directory must already exist.'
}

# An explicit source inventory excludes local build artifacts and credentials.
# -Force retains the desktop templates under files/skel/.config.
$entries = @('README.md', 'CHANGELOG.md', 'LICENSE', 'docs', 'installer', 'scripts', 'ports', 'poudriere', 'tests')
$sourceFiles = foreach ($entry in $entries) {
    $entryPath = Join-Path $projectRoot $entry
    if (Test-Path -LiteralPath $entryPath -PathType Container) {
        Get-ChildItem -LiteralPath $entryPath -Recurse -Force -File
    } else {
        Get-Item -LiteralPath $entryPath
    }
}
$manifestLines = foreach ($sourceFile in ($sourceFiles | Sort-Object FullName)) {
    $relativePath = $sourceFile.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
    $digest = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$digest  $relativePath"
}
[IO.File]::WriteAllText((Join-Path $projectRoot 'MANIFEST.sha256'),
    (($manifestLines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))

& tar -czf $archivePath -C $projectRoot @entries MANIFEST.sha256
if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Output "Source files: $($sourceFiles.Count)"
Write-Output "Archive: $archivePath"
Write-Output "SHA256: $archiveHash"
