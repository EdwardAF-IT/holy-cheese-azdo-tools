param (
    [string] $MetadataRoot,
    [string] $OutputPath
)

Write-Host "🔍 Scanning for artifact-metadata.json files in: $MetadataRoot"

Write-Host "🔍 Listing all files under $MetadataRoot:"
Get-ChildItem -Path $MetadataRoot -Recurse | ForEach-Object {
    Write-Host "📄 $($_.FullName)"
}

Get-ChildItem "$(Pipeline.Workspace)" -Directory | ForEach-Object {
    Write-Host "📁 Folder: $($_.FullName)"
}

$merged = @()
Get-ChildItem -Path $MetadataRoot -Recurse -Filter artifact-metadata.json | ForEach-Object {
    try {
        $content = Get-Content $_.FullName | ConvertFrom-Json
        $merged += $content
        Write-Host "✅ Merged: $($_.FullName)"
    } catch {
        Write-Host "❌ Failed to parse: $($_.FullName)"
    }
}

if ($merged.Count -eq 0) {
    Write-Warning "⚠️ No metadata files found—writing empty manifest."
    @() | ConvertTo-Json -Depth 5 | Set-Content $OutputPath
} else {
    $merged | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
    Write-Host "📄 Final merged manifest written to: $OutputPath"

    if (Test-Path $OutputPath) {
        Write-Host "✅ Verified manifest exists at: $OutputPath"
    } else {
        Write-Host "❌ Manifest write failed—file not found at: $OutputPath"
        exit 1
    }
}
