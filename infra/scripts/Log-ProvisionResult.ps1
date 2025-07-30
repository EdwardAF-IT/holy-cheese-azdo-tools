param (
  [string]$EnvName,
  [int]$HostType,
  [int]$Result,
  [string]$ResultFilePath
)

$record = @{
  EnvName  = $EnvName
  HostType = $HostType
  Result   = $Result
}

# Ensure folder exists
$folder = Split-Path $ResultFilePath -Parent
if (-not (Test-Path $folder)) {
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  Write-Host "📁 Created folder: $folder"
}

# Initialize file if it doesn't exist
if (-not (Test-Path $ResultFilePath)) {
  "[]" | Set-Content $ResultFilePath
  Write-Host "📄 Initialized result file: $ResultFilePath"
}

# Read and validate current content
try {
  $existing = Get-Content $ResultFilePath -Raw | ConvertFrom-Json
  if ($existing -isnot [System.Collections.IEnumerable]) {
    $existing = @($existing)
  }
} catch {
  Write-Host "⚠️ Failed to parse existing file — starting fresh"
  $existing = @()
}

$existing += $record

# Write clean flattened array
@($existing) | ConvertTo-Json -Depth 3 | Set-Content $ResultFilePath

Write-Host "✅ Logged: Env=$EnvName, HostType=$HostType, Result=$Result"
