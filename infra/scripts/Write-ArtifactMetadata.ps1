param (
  [string] $EnvName,
  [string] $HostType,
  [string] $ResultFilePath,
  [string] $Commit,
  [string] $Version,
  [string] $OutputPath,
  [string] $ResourceGroupName,
  [string] $FunctionAppName,
  [string] $KeyVaultName,
  [string] $StorageAccountName
)

$metadata = @{
  EnvName             = $EnvName
  HostType            = $HostType
  ResultFilePath      = $ResultFilePath
  Commit              = $Commit
  Version             = $Version
  Timestamp           = (Get-Date).ToString("o")
  ResourceGroupName   = $ResourceGroupName
  FunctionAppName     = $FunctionAppName
  KeyVaultName        = $KeyVaultName
  StorageAccountName  = $StorageAccountName
}

$folder = Split-Path -Path $OutputPath
if (-not (Test-Path $folder)) {
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

$metadata | ConvertTo-Json -Depth 5 | Set-Content $OutputPath
Write-Host "✅ Metadata written to $OutputPath"
