<#
.SYNOPSIS
    Builds KmyTarkovApi against a local SPT installation and installs the result.

.DESCRIPTION
    Restores the NuGet packages, compiles the plugin projects and copies the
    assemblies into the plugin folder of the given SPT install.

.PARAMETER SptGamePath
    Root folder of the SPT installation (the one containing EscapeFromTarkov.exe).

.PARAMETER PluginDir
    Destination plugin folder. Defaults to <SptGamePath>\BepInEx\plugins\kmyuhkyuk-KmyTarkovApi.

.PARAMETER Configuration
    Build configuration, defaults to Release.

.PARAMETER SkipDeploy
    Only build, do not copy anything into the game folder.
#>
[CmdletBinding()]
param(
    [string]$SptGamePath = 'D:\Games\SPT 4.1.6 essential',
    [string]$PluginDir,
    [string]$Configuration = 'Release',
    [switch]$SkipDeploy
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
if (-not $PluginDir) { $PluginDir = Join-Path $SptGamePath 'BepInEx\plugins\kmyuhkyuk-KmyTarkovApi' }

function Find-MSBuild {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $path = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
        if ($path) { return $path }
    }
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    throw 'MSBuild.exe not found. Install Visual Studio 2022 Build Tools with the ".NET desktop build tools" workload.'
}

if (-not (Test-Path (Join-Path $SptGamePath 'EscapeFromTarkov.exe'))) {
    throw "No SPT installation found at '$SptGamePath' (EscapeFromTarkov.exe missing)."
}

$msbuild = Find-MSBuild
Write-Host "MSBuild : $msbuild"
Write-Host "SPT path: $SptGamePath"

$nuget = Join-Path $repo 'nuget.exe'
if (-not (Test-Path $nuget)) {
    Write-Host 'nuget.exe not present, downloading...'
    Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget -UseBasicParsing
}
$projects = @(
    'KmyTarkovReflection\KmyTarkovReflection.csproj',
    'KmyTarkovUtils\KmyTarkovUtils.csproj',
    'KmyTarkovConfiguration\KmyTarkovConfiguration.csproj',
    'KmyTarkovApi\KmyTarkovApi.csproj',
    'ConfigurationTest\ConfigurationTest.csproj'
)

Write-Host '=== nuget restore ==='
# Restore the plugin projects individually: Build/Build.csproj pulls packages
# (CopyBuildAssembly 1.0.0) that are not available on nuget.org any more and the
# packer is not needed to produce the plugin.
foreach ($p in $projects) {
    $projPath = Join-Path $repo $p
    if (-not (Test-Path (Join-Path (Split-Path $projPath) 'packages.config'))) { continue }
    & $nuget restore $projPath -PackagesDirectory (Join-Path $repo 'packages') -NonInteractive
    if ($LASTEXITCODE -ne 0) { throw "nuget restore failed for $p (exit code $LASTEXITCODE)" }
}

foreach ($p in $projects) {
    Write-Host "=== $p ==="
    & $msbuild (Join-Path $repo $p) "/p:Configuration=$Configuration" /p:Platform=AnyCPU "/p:SPTGamePath=$SptGamePath" /v:minimal /nologo /m
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $p" }
}

if ($SkipDeploy) { Write-Host 'Built, deployment skipped.'; return }

New-Item -ItemType Directory -Force -Path $PluginDir, (Join-Path $PluginDir 'localized') | Out-Null
$files = @(
    @{ src = 'KmyTarkovApi\bin\Release\KmyTarkovApi.dll'; dst = 'KmyTarkovApi.dll' },
    @{ src = 'KmyTarkovUtils\bin\Release\KmyTarkovUtils.dll'; dst = 'KmyTarkovUtils.dll' },
    @{ src = 'KmyTarkovReflection\bin\Release\KmyTarkovReflection.dll'; dst = 'KmyTarkovReflection.dll' },
    @{ src = 'KmyTarkovConfiguration\bin\Release\KmyTarkovConfiguration.dll'; dst = 'KmyTarkovConfiguration.dll' },
    @{ src = 'ConfigurationTest\bin\Release\ConfigurationTest.dll'; dst = 'ConfigurationTest.dll' },
    @{ src = 'KmyTarkovConfiguration\bin\Release\HtmlAgilityPack.dll'; dst = 'HtmlAgilityPack.dll' },
    @{ src = 'KmyTarkovConfiguration\bin\Release\Crc32.NET.dll'; dst = 'Crc32.NET.dll' }
)
foreach ($f in $files) {
    Copy-Item -LiteralPath (Join-Path $repo $f.src) -Destination (Join-Path $PluginDir $f.dst) -Force
}
foreach ($lang in 'en','zh') {
    Copy-Item -LiteralPath (Join-Path $repo "Build\localized\$lang.json") -Destination (Join-Path $PluginDir "localized\$lang.json") -Force
}

$bundle = Join-Path $PluginDir 'bundles\kmytarkovconfiguration.bundle'
if (-not (Test-Path $bundle)) {
    Write-Warning "Missing $bundle - the in-game configuration UI will not load. See BUILDING.md."
}

Write-Host ''
Write-Host "Installed to: $PluginDir"
Get-ChildItem $PluginDir -Recurse -File | Select-Object @{n='file';e={$_.FullName.Substring($PluginDir.Length)}},Length | Format-Table -AutoSize
