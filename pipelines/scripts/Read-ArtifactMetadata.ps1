param (
    [string] $MetadataPath
)

if (-not (Test-Path $MetadataPath)) {
    Write-Error "Metadata file not found: {0}".Format($MetadataPath)
    exit 1
}

$meta = Get-Content $MetadataPath | ConvertFrom-Json
Write-Host "✅ Metadata loaded from {0}".Format($MetadataPath)
Write-Host "##vso[task.setvariable variable=provisionResultPath]{0}".Format($meta.ResultFilePath)
