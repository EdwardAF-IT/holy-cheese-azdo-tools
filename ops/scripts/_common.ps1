# Utility helper to load YAML with a fallback
function Import-YamlSafely {
  param([Parameter(Mandatory)][string] $Path)
  if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    try {
      Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } catch {
      Write-Error "Failed to install powershell-yaml. Ensure internet access on the agent or pre-bake the module."
      throw
    }
    Import-Module powershell-yaml -ErrorAction Stop
  }
  return (Get-Content $Path -Raw | ConvertFrom-Yaml)
}
