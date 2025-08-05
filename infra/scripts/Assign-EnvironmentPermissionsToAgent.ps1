# === CONFIGURATION ===
$org = "techwavellc"
$project = "holy-cheese"
$pat = "0UxgI8qhJQqhC7axwppFuEHx4cSXfl9DungYBDwvGI7DQWkyCXz8JQQJ99BHACAAAAAAAAAAAAASAZDO254M"

# === AUTH HEADERS ===
$authHeader = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
  Authorization = "Basic $authHeader"
  "Content-Type"  = "application/json"
}

# === STEP 1: Get Project Info ===
Write-Host "Interpolated Project Value: '$project'"
$url = [string]::Format("https://dev.azure.com/{0}/_apis/projects/{1}?api-version=7.1-preview.1", $org, $project)
Write-Host "✅ Project Info URL: $url"
$projectInfo = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
$projectId = $projectInfo.id
Write-Host "✅ Project ID: $projectId"

# === STEP 2: Prepare ACL Update ===
$namespaceId = "52d39943-cb85-4d7f-8fa8-c6baac873819"  # Library namespace
$identityDescriptor = "Microsoft.VisualStudio.Services.Graph.GraphGroup;vssgp.Uy0xLTktMTU1MTM3NDI0NS0yODI5NTEyNzM5LTI3MzE2ODg3NzMtMjM3Mzg0NzQ0Mi01OTg5NzM3NzMtMC0wLTAtMS0x"

$bodyObject = @{
  token = [string]::Format("project:{0}", $projectId)
  merge = $true
  accessControlEntries = @(
    @{
      descriptor = $identityDescriptor
      allow      = 1
      deny       = 0
    }
  )
}
$bodyJson = $bodyObject | ConvertTo-Json -Depth 10
Write-Host "🧾 ACL Payload:`n$bodyJson"

# === STEP 3: Submit ACL Update ===
$aclUrl = [string]::Format("https://vssps.dev.azure.com/{0}/_apis/accesscontrolentries/{1}?api-version=7.1-preview.1", $org, $namespaceId)
$response = Invoke-RestMethod -Uri $aclUrl -Method Post -Headers $headers -Body $bodyJson
Write-Host "✅ ACL Response:`n$response"

# === STEP 4: OPTIONAL: Validate ACL via alternate strategy ===
# Note: direct GET/POST ACL query endpoints are flaky across namespaces — consider skipping or inspecting $response manually.
Write-Host "🔍 Skipping ACL validation — rely on response and manual audit if needed"
