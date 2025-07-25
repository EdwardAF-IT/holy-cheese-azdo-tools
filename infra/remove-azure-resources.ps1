# Ensure you're signed in
#Install-Module -Name Az -AllowClobber -Force -Scope CurrentUser -Repository PSGallery
#Import-Module Az
#Connect-AzAccount -DeviceCode

# Get all matching resource groups
$targetRGs = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "AzdoTools*" }
$subId = (Get-AzContext).Subscription.Id

# Iterate through each matching RG
foreach ($rg in $targetRGs) {
    Write-Host "`nProcessing resource group:" $rg.ResourceGroupName -ForegroundColor Cyan

    $location = $rg.Location
    $keyVaultNames = @()
    $storageAccountNames = @()

    # Get all resources in this RG
    $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName

    foreach ($res in $resources) {
        Write-Host "Deleting resource:" $res.Name -ForegroundColor Yellow
        Remove-AzResource -ResourceId $res.ResourceId -Force -Verbose

        if ($res.Type -eq 'Microsoft.KeyVault/vaults') {
            $keyVaultNames += $res.Name
        } elseif ($res.Type -eq 'Microsoft.Storage/storageAccounts') {
            $storageAccountNames += $res.Name
        }
    }

    # Purge Key Vaults that were soft-deleted
    foreach ($kvName in $keyVaultNames) {
        Write-Host "Purging deleted Key Vault:" $kvName -ForegroundColor Magenta
        az keyvault purge --name $kvName
    }

    # Purge Storage Accounts that were soft-deleted
    foreach ($saName in $storageAccountNames) {
        Write-Host "Purging deleted Storage Account:" $saName -ForegroundColor Magenta
        az storage account purge --name $saName --location $location
    }

    # Delete the resource group itself
    Write-Host "Deleting resource group:" $rg.ResourceGroupName -ForegroundColor Red
    Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -Verbose
}

Write-Host "`nCleanup complete!" -ForegroundColor Green
