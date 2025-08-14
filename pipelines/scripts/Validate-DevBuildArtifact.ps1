function Next-Suffix {
    param ([string] $suffix)

    if (-not $suffix) { return "a" }

    $chars = $suffix.ToCharArray()
    $i = $chars.Length - 1
    $carry = $true

    while ($i -ge 0 -and $carry) {
        if ($chars[$i] -eq 'z') {
            $chars[$i] = 'a'
            $i--
        } else {
            $chars[$i] = [char]($chars[$i] + 1)
            $carry = $false
        }
    }

    if ($carry) {
        $chars = @('a') + $chars
    }

    return -join $chars
}

function Validate-DevBuildArtifact {
    param (
        [string] $Commit,
        [string] $ArtifactDir,
        [string] $ArtifactNamePrefix
    )

    $shortCommit = $Commit.Substring(0, 7)
    $baseVersion = [string]::Format("1.2.0.{0}", $shortCommit)
    $pattern = [string]::Format("{0}.*\.zip", $ArtifactNamePrefix + "-" + $baseVersion)

    $existing = Get-ChildItem $ArtifactDir -Filter "*.zip" | Where-Object {
        $_.Name -match $pattern
    }

    $suffixes = $existing.Name | ForEach-Object {
        if ($_ -match [string]::Format("{0}\.(.+)\.zip", [Regex]::Escape($ArtifactNamePrefix + "-" + $baseVersion))) {
            return $matches[1]
        }
    } | Sort-Object

    $last = $suffixes[-1]
    $next = Next-Suffix $last
    $version = [string]::Format("{0}.{1}", $baseVersion, $next)

    $artifactPath = Join-Path $ArtifactDir ([string]::Format("{0}-{1}.zip", $ArtifactNamePrefix, $version))

    if (-not (Test-Path $artifactPath)) {
        Write-Error ([string]::Format("Dev build artifact not found: {0}", $artifactPath))
        Write-Host ([string]::Format("##vso[task.complete result=Failed;]Dev build artifact missing for version {0}", $version))
        exit 1
    }

    Write-Host ([string]::Format("Dev build artifact found: {0}", $artifactPath))
    Write-Host ([string]::Format("##vso[task.setvariable variable=version]{0}", $version))
}
