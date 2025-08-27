<#
.SYNOPSIS
Restores, builds, tests, publishes, and zips the Function app.
#>
param(
  [Parameter()][string] $App = 'azdotools'
)
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/_common.ps1"
$cfg = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$spec = Import-YamlSafely -Path ([string]::Format($cfg.appBuildSpec, $App))

# Restore/build/test
if ($spec.restore) { Invoke-Expression $spec.restore }
if ($spec.build)   { Invoke-Expression $spec.build }
if ($spec.test)    { Invoke-Expression $spec.test }

# Publish
$projPath  = $cfg.paths.functionProject
$publishDir= $cfg.paths.publishDir
dotnet publish $projPath -c Release -o $publishDir

# Package
$pkg = $cfg.paths.packagePath
if (Test-Path $pkg) { Remove-Item $pkg -Force }
$pkgDir = Split-Path $pkg -Parent
New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($publishDir, $pkg)

Write-Host ([string]::Format("Package created at {0}", $pkg))
