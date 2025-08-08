param (
    [string] $Url
)

try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 10
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        Write-Error "Health check failed: Status {0}".Format($response.StatusCode)
        Write-Host "##vso[task.complete result=Failed;]Health check failed"
        exit 1
    }
    Write-Host "✅ Health check passed"
} catch {
    Write-Error "Health check error: {0}".Format($_)
    Write-Host "##vso[task.complete result=Failed;]Health check error"
    exit 1
}
