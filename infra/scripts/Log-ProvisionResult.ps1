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

if (-not (Test-Path $ResultFilePath)) {
  "[]" | Set-Content $ResultFilePath
  Write-Host "Result file not found — initializing empty array."
}

$json = Get-Content $ResultFilePath | ConvertFrom-Json
$json += $record
$json | ConvertTo-Json -Depth 3 | Set-Content $ResultFilePath

Write-Host ("Logged result for env '{0}', host type {1}, result {2}" -f $EnvName, $HostType, $Result)
