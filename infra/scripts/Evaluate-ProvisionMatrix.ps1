function Evaluate-ProvisionMatrix {
  param (
    [string]$ResultFilePath
  )

  if (-not (Test-Path $ResultFilePath)) {
    Write-Host "❌ Result file not found. Failing build."
    exit 1
  }

  $results = Get-Content $ResultFilePath | ConvertFrom-Json
  $hostTypes = @(0, 1, 2)

  # Group non-special environments
  $envGroups = $results | Where-Object { $_.env -notin @('shared', 'sub') } |
               Group-Object -Property env

  $envsWithAllHostCoverage = @()

  foreach ($group in $envGroups) {
    $env = $group.Name
    $hostCoverage = $hostTypes | ForEach-Object {
      $group.Group | Where-Object { $_.host -eq $_ -and $_.result -eq 1 }
    }
    if ($hostCoverage.Count -eq $hostTypes.Count) {
      $envsWithAllHostCoverage += $env
    }
  }

  $sharedOK = $results | Where-Object { $_.env -eq 'shared' -and $_.result -eq 1 }
  $subOK    = $results | Where-Object { $_.env -eq 'sub' -and $_.result -eq 1 }

  $envOK = $envsWithAllHostCoverage.Count -eq $envGroups.Count

  if ($envOK -and $sharedOK.Count -gt 0 -and $subOK.Count -gt 0) {
    Write-Host "✅ Provisioning matrix is complete."
    return $true
  } else {
    Write-Host "❌ Provisioning matrix is incomplete:"
    if (-not $envOK) {
      $missing = $envGroups | Where-Object { $_.Name -notin $envsWithAllHostCoverage } | Select-Object -ExpandProperty Name
      Write-Host "  - Missing host coverage for envs: $($missing -join ', ')"
    }
    if ($sharedOK.Count -eq 0) { Write-Host "  - 'shared' stage did not pass." }
    if ($subOK.Count -eq 0)    { Write-Host "  - 'sub' stage did not pass." }
    return $false
  }
}
