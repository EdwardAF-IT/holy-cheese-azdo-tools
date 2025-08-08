param (
    [string] $EnvName,
    [string] $HostType,
    [string] $ResultFilePath,
    [string] $Commit,
    [string] $Version,
    [string] $OutputPath
)

$metadata = @{
    EnvName         = $EnvName
    HostType        = $HostType
    ResultFilePath  = $ResultFilePath
    Commit          = $Commit
    Version         = $Version
    Timestamp       = (Get-Date).ToString("o")
}

$metadata | ConvertTo-Json -Depth 5 | Set-Content $OutputPath
Write-Host "✅ Metadata written to {0}".Format($OutputPath)
