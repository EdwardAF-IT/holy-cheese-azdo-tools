param (
    [string] $Url
)

try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 10

    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        Write-Error ([string]::Format("Health check failed: Status {0}", $response.StatusCode))
        Write-Host ([string]::Format("##vso[task.complete result=Failed;]Health check failed with status {0}", $response.StatusCode))
        exit 1
    }

    Write-Host ([string]::Format("Health check passed for URL: {0}", $Url))
}
catch {
    Write-Error ([string]::Format("Health check error: {0}", $_.Exception.Message))
    Write-Host ([string]::Format("##vso[task.complete result=Failed;]Health check error for URL: {0}", $Url))
    exit 1
}
