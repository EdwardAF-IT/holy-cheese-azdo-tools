param (
    [string] $ResultFilePath,
    [string] $EnvName
)

if (-not (Test-Path $ResultFilePath)) {
    Write-Error "Provisioning result file not found: {0}".Format($ResultFilePath)
    exit 1
}

$raw = Get-Content $ResultFilePath | ConvertFrom-Json
$testSuccess = $raw | Where-Object { $_.EnvName -eq $EnvName -and $_.Result -eq 0 }

if (-not $testSuccess) {
    Write-Error "❌ Provisioning failed or missing for environment: {0}".Format($EnvName)
    Write-Host "##vso[task.complete result=Failed;]Provisioning validation failed"
    exit 1
}

Write-Host "✅ Provisioning succeeded for environment: {0}".Format($EnvName)
