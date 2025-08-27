param([string]$Location = 'centralus')

. "$PSScriptRoot/_common.ps1"
$cfg = Import-YamlSafely -Path (Join-Path $PSScriptRoot "..\config.yml")
$bicep = $cfg.paths.bicepShared
$rg = $cfg.shared.resourceGroup

$tags = @{
  org = $cfg.globals.org
  app = $cfg.globals.app
  scope = 'shared'
}

az account set --subscription $cfg.globals.subscriptionId
az group create -n $rg -l $Location --tags $tags | Out-Null

az deployment group create `
  -g $rg `
  -f $bicep `
  -p location=$Location tags=$tags `
  --only-show-errors
