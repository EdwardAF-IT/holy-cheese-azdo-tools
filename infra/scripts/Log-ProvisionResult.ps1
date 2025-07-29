param (
  [string]$EnvName,
  [int]$HostType,
  [int]$Result,
  [string]$ResultFilePath
)

$record = @{
  env    = $EnvName
  host   = $HostType
  result = $Result
}

# Ensure folder exists
$folder = Split-Path $ResultFilePath -Parent
if (-not (Test-Path $folder)) {
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  Write-Host "Created missing folder: $folder"
}

# Initialize file if it doesn't exist
Write-Host $ResultFilePath
if (-not (Test-Path $ResultFilePath)) {
  "[]" | Set-Content $ResultFilePath
  Write-Host "Result file not found — initializing empty array."
}

# Append record
$json = Get-Content $ResultFilePath | ConvertFrom-Json
$json += $record
$json | ConvertTo-Json -Depth 3 | Set-Content $ResultFilePath

Write-Host ("Logged result for env '{0}', host type {1}, result {2}" -f $EnvName, $HostType, $Result)