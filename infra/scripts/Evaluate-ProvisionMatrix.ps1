function Evaluate-ProvisionMatrix {
  param (
    [Object[]]$Results
  )

  $hostTypes = @(0, 1, 2)

  $envGroups = $Results | Where-Object { $_.env -notin @('shared', 'sub') } |
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

  $sharedOK = $Results | Where-Object { $_.env -eq 'shared' -and $_.result -eq 1 }
  $subOK    = $Results | Where-Object { $_.env -eq 'sub' -and $_.result -eq 1 }

  $envOK = $envsWithAllHostCoverage.Count -eq $envGroups.Count

  return @{
    Success = ($envOK -and $sharedOK.Count -gt 0 -and $subOK.Count -gt 0)
    MissingEnvs = if (-not $envOK) { $envGroups | Where-Object { $_.Name -notin $envsWithAllHostCoverage } | Select-Object -ExpandProperty Name } else { @() }
    SharedPassed = ($sharedOK.Count -gt 0)
    SubPassed    = ($subOK.Count -gt 0)
  }
}
