function Download-Artifact {
    param (
        [string] $artifactName,
        [string] $targetPath
    )

    $collectionUri = $env:SYSTEM_COLLECTIONURI       # e.g., https://dev.azure.com/myorg/
    $project = $env:SYSTEM_TEAMPROJECT               # e.g., MyProject
    $pipelineId = $env:BUILD_DEFINITIONID            # Current pipeline ID
    $runId = $env:BUILD_BUILDID                      # Current run ID
    $accessToken = $env:SYSTEM_ACCESSTOKEN           # OAuth token provided by agent

    $headers = @{
        Authorization = "Bearer " + $accessToken
    }

    $artifactListUri = [string]::Format("{0}{1}/_apis/build/builds/{2}/artifacts?api-version=7.1-preview.5",
    $collectionUri, $project, $runId)

    try {
        Write-Host ([string]::Format("🔍 Querying artifact list from: {0}", $artifactListUri))
        $response = Invoke-RestMethod -Uri $artifactListUri -Headers $headers -Method Get
        $artifact = $response.value | Where-Object { $_.name -eq $artifactName }

        if ($null -eq $artifact) {
            Write-Host ([string]::Format("⚠️ Artifact not found: {0}", $artifactName))
            return
        }

        $downloadUrl = $artifact.resource.downloadUrl
        $zipPath = $targetPath + ".zip"

        Write-Host ([string]::Format("🔽 Downloading artifact: {0}", $artifactName))
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -Headers $headers

        Write-Host ([string]::Format("📦 Extracting to: {0}", $targetPath))
        Expand-Archive -Path $zipPath -DestinationPath $targetPath -Force
        Remove-Item -Path $zipPath -Force

        Write-Host ([string]::Format("✅ Downloaded and extracted: {0}", $artifactName))
    } catch {
        Write-Host ([string]::Format("❌ Error downloading artifact '{0}': {1}", $artifactName, $_.Exception.Message))
    }
}
