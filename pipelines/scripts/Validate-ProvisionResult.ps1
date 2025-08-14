param (
    [string] $ResultFilePath,
    [string] $EnvName
)

if (-not (Test-Path $ResultFilePath)) {
    Write-Error ([string]::Format("Provisioning result file not found: {0}", $ResultFilePath))
    exit 1
}

$raw = Get-Content $ResultFilePath | ConvertFrom-Json
$testSuccess = $raw | Where-Object { $_.EnvName -eq $EnvName -and $_.Result -eq 0 }

if (-not $testSuccess) {
    Write-Error ([string]::Format("Provisioning failed or missing for environment: {0}", $EnvName))
    Write-Host ([string]::Format("##vso[task.complete result=Failed;]Provisioning validation failed for {0}", $EnvName))
    exit 1
}

Write-Host ([string]::Format("Provisioning succeeded for environment: {0}", $EnvName))
