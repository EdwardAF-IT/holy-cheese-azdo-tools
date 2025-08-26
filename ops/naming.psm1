# naming.psm1
# Single source of naming truth. All scripts and Bicep consume names produced here.

function New-ResourceName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Org,        # e.g., 'holycheese'
    [Parameter(Mandatory)] [string] $App,        # e.g., 'azdotools'
    [Parameter(Mandatory)] [string] $Env,        # e.g., 'dev', 'test', 'prod'
    [Parameter(Mandatory)] [string] $RegionCode, # e.g., 'cus', 'eus2'
    [Parameter(Mandatory)]
    [ValidateSet(
      # rg  = Resource Group
      # func= Function App
      # asp = App Service Plan (Consumption/Premium)
      # stg = Storage Account (for AzureWebJobsStorage and package hosting)
      # ai  = Application Insights
      # kv  = Key Vault (shared or env-scoped)
      'rg','func','asp','stg','ai','kv'
    )]
    [string] $Suffix
  )

  # General base convention: org-app-env-region-suffix
  $base = [string]::Format("{0}-{1}-{2}-{3}-{4}",
    $Org.ToLower(), $App.ToLower(), $Env.ToLower(), $RegionCode.ToLower(), $Suffix.ToLower())

  switch ($Suffix) {
    'stg' {
      # Storage has stricter rules: 3-24 chars, lowercase alphanumeric only
      $stg = [string]::Format("{0}{1}{2}{3}",
        $Org.ToLower() -replace '[^a-z0-9]', '',
        $App.ToLower() -replace '[^a-z0-9]', '',
        $Env.ToLower() -replace '[^a-z0-9]', '',
        'stg001')
      $stg = $stg.Substring(0, [Math]::Min(24, $stg.Length))
      return $stg
    }
    default { return $base }
  }
}

Export-ModuleMember -Function New-ResourceName
