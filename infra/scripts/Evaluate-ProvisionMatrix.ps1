function Evaluate-ProvisionMatrix {
  param (
    [Object[]]$Results
  )

  # ───────────────────────────────────────────────────────────────
  # Constant Definitions
  # These help maintain clarity and reduce risk of typos in logic
  # ───────────────────────────────────────────────────────────────
  $HOST_TYPES     = @(0, 1, 2)                   # 0 = Hosted, 1 = Local Fallback, 2 = Local Specified
  $SPECIAL_ENVS   = @('shared', 'sub')           # Non-triad stages requiring independent evaluation
  $SUCCESS_VALUE  = 0                            # Status code indicating provisioning success

  # ───────────────────────────────────────────────────────────────
  # Log received results for transparency
  # ───────────────────────────────────────────────────────────────
  Write-Host "`n📥 Total input results: $($Results.Count)"
  $Results | ForEach-Object {
    $hostLabel = switch ($_.HostType) {
      0 { 'Hosted' }
      1 { 'Local Fallback' }
      2 { 'Local Specified' }
      default { 'Unknown' }
    }
    $status = if ($_.Result -eq $SUCCESS_VALUE) { '✅ Success' } else { '❌ Failure' }
    Write-Host "• Env=$($_.EnvName), Host=$hostLabel, Status=$status"
  }

  # ───────────────────────────────────────────────────────────────
  # Group results by environment, excluding 'shared' and 'sub'
  # These are the environments expected to appear in triads
  # ───────────────────────────────────────────────────────────────
  $envGroups = $Results | Where-Object { $_.EnvName -notin $SPECIAL_ENVS } |
               Group-Object -Property EnvName

  Write-Host "`n📊 Triad environment groups: $($envGroups.Count)"
  if ($envGroups.Count -eq 0) { Write-Host "⚠️ No triad environments found." }

  # ───────────────────────────────────────────────────────────────
  # Identify environments where provisioning succeeded at least once
  # Success can come from any host type (hosted, local, personal)
  # ───────────────────────────────────────────────────────────────
  $envsWithSuccess = $envGroups | Where-Object {
    ($_.Group | Where-Object { $_.Result -eq $SUCCESS_VALUE }).Count -gt 0
  } | Select-Object -ExpandProperty Name

  Write-Host "`n✅ Triad environments with at least one success:"
  if ($envsWithSuccess.Count -eq 0) {
    Write-Host "  • (None succeeded)"
  } else {
    $envsWithSuccess | ForEach-Object { Write-Host "  • $_" }
  }

  # ✔ Check that all triad environments are represented with success
  $envOK = $envsWithSuccess.Count -eq $envGroups.Count
  if (-not $envOK) {
    $missingEnvs = $envGroups | Where-Object { $_.Name -notin $envsWithSuccess } | Select-Object -ExpandProperty Name
    Write-Host "`n❌ Missing successful triad environments:"
    $missingEnvs | ForEach-Object { Write-Host "  • $_" }
  }

  # ───────────────────────────────────────────────────────────────
  # Independently confirm success for 'shared' and 'sub'
  # These are essential standalone stages, not part of triads
  # ───────────────────────────────────────────────────────────────
  $sharedOK = $Results | Where-Object { $_.EnvName -eq 'shared' -and $_.Result -eq $SUCCESS_VALUE }
  $subOK    = $Results | Where-Object { $_.EnvName -eq 'sub' -and $_.Result -eq $SUCCESS_VALUE }

  Write-Host "`n🔐 Shared stage success count: $($sharedOK.Count)"
  Write-Host "🔐 Sub stage success count: $($subOK.Count)"

  if ($sharedOK.Count -eq 0) { Write-Host "❌ 'shared' stage failed." }
  if ($subOK.Count -eq 0)    { Write-Host "❌ 'sub' stage failed." }

  # ───────────────────────────────────────────────────────────────
  # Return an object with diagnostics and success state
  # Includes missing environments to aid debugging
  # ───────────────────────────────────────────────────────────────
  return @{
    Success      = ($envOK -and $sharedOK.Count -gt 0 -and $subOK.Count -gt 0)
    MissingEnvs  = $envGroups | Where-Object { $_.Name -notin $envsWithSuccess } | Select-Object -ExpandProperty Name
    SharedPassed = ($sharedOK.Count -gt 0)
    SubPassed    = ($subOK.Count -gt 0)
  }
}
