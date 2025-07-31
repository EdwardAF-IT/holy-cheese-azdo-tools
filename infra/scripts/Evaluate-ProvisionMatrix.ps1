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
  # Group results by environment, excluding 'shared' and 'sub'
  # These are the environments expected to appear in triads
  # ───────────────────────────────────────────────────────────────
  $envGroups = $Results | Where-Object { $_.env -notin $SPECIAL_ENVS } |
               Group-Object -Property env

  # ───────────────────────────────────────────────────────────────
  # Identify environments where provisioning succeeded at least once
  # Success can come from any host type (hosted, local, personal)
  # ───────────────────────────────────────────────────────────────
  $envsWithSuccess = $envGroups | Where-Object {
    ($_.Group | Where-Object { $_.result -eq $SUCCESS_VALUE }).Count -gt 0
  } | Select-Object -ExpandProperty Name

  # ✔ Check that all triad environments are represented with success
  $envOK = $envsWithSuccess.Count -eq $envGroups.Count

  # ───────────────────────────────────────────────────────────────
  # Independently confirm success for 'shared' and 'sub'
  # These are essential standalone stages, not part of triads
  # ───────────────────────────────────────────────────────────────
  $sharedOK = $Results | Where-Object { $_.env -eq 'shared' -and $_.result -eq $SUCCESS_VALUE }
  $subOK    = $Results | Where-Object { $_.env -eq 'sub' -and $_.result -eq $SUCCESS_VALUE }

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
