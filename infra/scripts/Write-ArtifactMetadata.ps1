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

$folder = Split-Path -Path $OutputPath
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

$metadata | ConvertTo-Json -Depth 5 | Set-Content $OutputPath
[string]::Format("✅ Metadata written to {0}", $OutputPath)
