param (
  [string] $ManifestPath,
  [string] $Environment,
  [string] $Version,
  [string] $Commit,
  [string] $Notes,
  [string] $ArtifactPath,
  [int]    $Result,
  [string] $HostType = "",
  [string] $ResourceGroupName = "",
  [string] $SubscriptionId = "",
  [string] $SharedInsightsName = "",
  [string] $SharedHostingPlanName = "",
  [string] $FunctionAppName = "",
  [string] $KeyVaultName = "",
  [string] $StorageAccountName = ""
)

# ───────────────────────────────────────────────────────────────
# Safely load and convert existing manifest to hashtable
# ───────────────────────────────────────────────────────────────
$existing = @{}
if (Test-Path $ManifestPath) {
  try {
    $raw = Get-Content $ManifestPath | ConvertFrom-Json
    foreach ($prop in $raw.PSObject.Properties) {
      $existing[$prop.Name] = $prop.Value
    }
    Write-Host "📄 Loaded existing manifest with $($existing.Keys.Count) environments"
  } catch {
    Write-Host "⚠️ Failed to parse existing manifest — starting fresh"
  }
} else {
  Write-Host "📄 No existing manifest found — starting fresh"
}

# ───────────────────────────────────────────────────────────────
# Build new environment block
# ───────────────────────────────────────────────────────────────
$entry = @{
  version            = $Version
  commit             = $Commit
  notes              = $Notes
  artifactPath       = $ArtifactPath
  result             = $Result
  hostType           = $HostType
  resourceGroup      = $ResourceGroupName
  subscriptionId     = $SubscriptionId
  sharedInsightsName = $SharedInsightsName
  sharedHostingPlanName = $SharedHostingPlanName
  functionAppName    = $FunctionAppName
  keyVaultName       = $KeyVaultName
  storageAccountName = $StorageAccountName
  timestamp          = (Get-Date).ToString("o")
}

# ───────────────────────────────────────────────────────────────
# Update the manifest under the environment key
# ───────────────────────────────────────────────────────────────
$existing[$Environment] = $entry

# ───────────────────────────────────────────────────────────────
# Ensure target directory exists
# ───────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Split-Path $ManifestPath) -Force | Out-Null

# ───────────────────────────────────────────────────────────────
# Write updated manifest
# ───────────────────────────────────────────────────────────────
$updatedJson = $existing | ConvertTo-Json -Depth 5
$updatedJson | Out-File -FilePath $ManifestPath -Encoding UTF8

Write-Host "✅ Manifest updated for environment: $Environment"
