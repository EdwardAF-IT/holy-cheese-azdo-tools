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
    $baseVersion = "1.2.0.{0}".Format($shortCommit)
    $pattern = "{0}.*\.zip".Format($ArtifactNamePrefix + "-" + $baseVersion)

    $existing = Get-ChildItem $ArtifactDir -Filter "*.zip" | Where-Object {
        $_.Name -match $pattern
    }

    $suffixes = $existing.Name | ForEach-Object {
        if ($_ -match "{0}\.(.+)\.zip".Format([Regex]::Escape($ArtifactNamePrefix + "-" + $baseVersion))) {
            return $matches[1]
        }
    } | Sort-Object

    $last = $suffixes[-1]
    $next = Next-Suffix $last
    $version = "{0}.{1}".Format($baseVersion, $next)

    $artifactPath = Join-Path $ArtifactDir "{0}-{1}.zip".Format($ArtifactNamePrefix, $version)
    if (-not (Test-Path $artifactPath)) {
        Write-Error "❌ Dev build artifact not found: {0}".Format($artifactPath)
        Write-Host "##vso[task.complete result=Failed;]Dev build artifact missing"
        exit 1
    }

    Write-Host "✅ Dev build artifact found: {0}".Format($artifactPath)
    Write-Host "##vso[task.setvariable variable=version]{0}".Format($version)
}
