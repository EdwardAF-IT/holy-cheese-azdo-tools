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

# Load existing manifest if it exists
if (Test-Path $ManifestPath) {
    $existing = Get-Content $ManifestPath | ConvertFrom-Json
} else {
    $existing = @{}
}

# Build new environment block
$entry = @{
    version = $Version
    commit = $Commit
    notes = $Notes
    artifactPath = $ArtifactPath
    result = $Result
    hostType = $HostType
    resourceGroup = $ResourceGroupName
    subscriptionId = $SubscriptionId
    sharedInsightsName = $SharedInsightsName
    sharedHostingPlanName = $SharedHostingPlanName
    functionAppName = $FunctionAppName
    keyVaultName = $KeyVaultName
    storageAccountName = $StorageAccountName
    timestamp = (Get-Date).ToString("o")
}

# Load existing manifest if it exists
if (Test-Path $ManifestPath) {
    $existing = Get-Content $ManifestPath | ConvertFrom-Json
    $existing = @{} + $existing  # Cast to hashtable
} else {
    $existing = @{}
}

# Update the manifest under the environment key
$existing[$Environment] = $entry

# Ensure target directory exists
New-Item -ItemType Directory -Path (Split-Path $ManifestPath) -Force | Out-Null

# Write updated manifest
$updatedJson = $existing | ConvertTo-Json -Depth 5
$updatedJson | Out-File -FilePath $ManifestPath -Encoding UTF8

Write-Host "✅ Manifest updated for environment: $Environment"
