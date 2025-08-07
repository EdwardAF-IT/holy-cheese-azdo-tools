# === CONFIGURATION ===
$org = "techwavellc"
$project = "holy-cheese"
$pat = "0UxgI8qhJQqhC7axwppFuEHx4cSXfl9DungYBDwvGI7DQWkyCXz8JQQJ99BHACAAAAAAAAAAAAASAZDO254M"

$headers = @{
  Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
  "Content-Type" = "application/json"
}

# === Get Environments ===
$envUrl = "https://dev.azure.com/{0}/{1}/_apis/distributedtask/environments?api-version=7.1-preview.1" -f $org, $project
$envResponse = Invoke-RestMethod -Uri $envUrl -Method Get -Headers $headers

$environmentMap = @{}
foreach ($env in $envResponse.value) {
  $environmentMap[$env.name] = $env.id
  Write-Host "🌱 Environment: $($env.name) | ID: $($env.id)"
}

# === Resolve Descriptor ===
$groupName = "Project Collection Build Service Accounts"
$groupsUrl = "https://vssps.dev.azure.com/{0}/_apis/graph/groups?api-version=7.1-preview.1" -f $org
$groupsResponse = Invoke-RestMethod -Uri $groupsUrl -Method Get -Headers $headers
$descriptor = ($groupsResponse.value | Where-Object { $_.displayName -eq $groupName }).descriptor
Write-Host "🔍 Found Descriptor: $descriptor"

# === Assign Roles with Logging ===
foreach ($envName in $environmentMap.Keys) {
  $environmentId = $environmentMap[$envName]
  $roleName = "Administrator"
  $roleUrl = "https://dev.azure.com/{0}/{1}/_apis/securityroles/scopes/project/environment/{2}/roleassignments?api-version=7.1-preview.1" -f $org, $project, $environmentId

  $roleBody = @{
    roleName = $roleName
    userId   = $descriptor
  } | ConvertTo-Json -Depth 10

  Write-Host "`n🔗 Attempting Role Assignment for '$envName'"
  Write-Host "URL: $roleUrl"
  Write-Host "Body: $($roleBody | Out-String)"

  try {
    $roleResponse = Invoke-RestMethod -Uri $roleUrl -Method Post -Headers $headers -Body $roleBody
    Write-Host "✅ Role '$roleName' assigned to '$groupName' for environment '$envName'"
  } catch {
    Write-Host "❌ Failed to assign role to '$envName'"
    Write-Host "🧨 Error Message: $($_.Exception.Message)"
    Write-Host "📜 Raw Response: $($_ | Out-String)"
  }
}