function Evaluate-ProvisionMatrix {
  param (
    [hashtable]$Manifest
  )

  $HOST_TYPES    = @(0, 1, 2)
  $SPECIAL_ENVS  = @('shared', 'sub')
  $SUCCESS_VALUE = 0

  $envKeys = $Manifest.Keys
  $triadEnvs = $envKeys | Where-Object { $_ -notin $SPECIAL_ENVS }

  Write-Host "`n📥 Total environments in manifest: $($envKeys.Count)"
  foreach ($env in $envKeys) {
    $entry = $Manifest[$env]
    $hostLabel = switch ($entry.hostType) {
      0 { 'Hosted' }
      1 { 'Local Fallback' }
      2 { 'Local Specified' }
      default { 'Unknown' }
    }
    $status = if ($entry.result -eq $SUCCESS_VALUE) { '✅ Success' } else { '❌ Failure' }
    Write-Host "• Env=$env, Host=$hostLabel, Status=$status"
  }

  # Group triad environments
  $envsWithSuccess = $triadEnvs | Where-Object {
    $Manifest[$_].result -eq $SUCCESS_VALUE
  }

  Write-Host "`n✅ Triad environments with success:"
  if ($envsWithSuccess.Count -eq 0) {
    Write-Host "  • (None succeeded)"
  } else {
    $envsWithSuccess | ForEach-Object { Write-Host "  • $_" }
  }

  $envOK = $envsWithSuccess.Count -eq $triadEnvs.Count
  $missingEnvs = $triadEnvs | Where-Object { $_ -notin $envsWithSuccess }

  if (-not $envOK) {
    Write-Host "`n❌ Missing successful triad environments:"
    $missingEnvs | ForEach-Object { Write-Host "  • $_" }
  }

  $sharedPassed = ($Manifest.ContainsKey('shared') -and $Manifest['shared'].result -eq $SUCCESS_VALUE)
  $subPassed    = ($Manifest.ContainsKey('sub')    -and $Manifest['sub'].result    -eq $SUCCESS_VALUE)

  Write-Host "`n🔐 Shared stage passed: $sharedPassed"
  Write-Host "🔐 Sub stage passed: $subPassed"

  if (-not $sharedPassed) { Write-Host "❌ 'shared' stage failed." }
  if (-not $subPassed)    { Write-Host "❌ 'sub' stage failed." }

  return @{
    Success      = ($envOK -and $sharedPassed -and $subPassed)
    MissingEnvs  = $missingEnvs
    SharedPassed = $sharedPassed
    SubPassed    = $subPassed
  }
}
