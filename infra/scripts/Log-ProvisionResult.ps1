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
  Write-Host ("Created missing folder: {0}" -f $folder)
}

# Initialize file if it doesn't exist
Write-Host ("Resultfilepath {0}" -f $ResultFilePath)
if (-not (Test-Path $ResultFilePath)) {
  "[]" | Set-Content $ResultFilePath
  Write-Host ("Result file not found.. initializing empty array.")
}

# Load and normalize existing content
try {
  $existingContent = Get-Content $ResultFilePath -Raw | ConvertFrom-Json
  if ($existingContent -isnot [System.Collections.IEnumerable]) {
    $existingContent = @($existingContent)
  }
} catch {
  Write-Host "⚠️ Could not read existing content, starting fresh."
  $existingContent = @()
}

# Append the record
$existingContent += $record

# Save as clean JSON
@($existingContent) | ConvertTo-Json -Depth 3 | Set-Content $ResultFilePath

Write-Host ("✅ Logged result for env '{0}', host type {1}, result {2}" -f $EnvName, $HostType, $Result)
