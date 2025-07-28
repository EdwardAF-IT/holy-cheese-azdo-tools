param(
  [string]$EnvName,
  [int]$HostType,
  [int]$Result
)

$record = @{
  env    = $EnvName
  host   = $HostType
  result = $Result
}

$file = "$(Pipeline.Workspace)/provision-results.json"

if (-not (Test-Path $file)) {
  "[]" | Set-Content $file
}

$json = Get-Content $file | ConvertFrom-Json
$json += $record
$json | ConvertTo-Json -Depth 3 | Set-Content $file

Write-Host "✅ Logged result for env '$EnvName', host type $HostType, result $Result"
