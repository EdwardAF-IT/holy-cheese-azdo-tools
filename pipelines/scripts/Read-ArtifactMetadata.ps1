param (
    [string] $MetadataPath
)
Write-Host "🔍 Received MetadataPath: $MetadataPath"

if (-not (Test-Path $MetadataPath)) {
    Write-Error ([string]::Format("Metadata file not found: {0}", $MetadataPath))
    exit 1
}

$meta = Get-Content $MetadataPath | ConvertFrom-Json

Write-Host ([string]::Format("Metadata loaded from {0}", $MetadataPath))
Write-Host ([string]::Format("##vso[task.setvariable variable=provisionResultPath]{0}", $meta.ResultFilePath))
