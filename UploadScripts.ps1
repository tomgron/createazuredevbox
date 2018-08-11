# HERE WE ASSUME WE HAVE RESOURCEGROUP AVAILABLE
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][string]$VMName,
    [Parameter(Mandatory=$true)][string]$ScriptToUpload,
    [Parameter(Mandatory=$true)][string]$RunFileName,
    [Parameter(Mandatory=$true)][string]$ScriptExtensionName,
    [Parameter(Mandatory=$true)][string]$LocationName
)

$StorageAccountName = -join ((97..122) | Get-Random -Count 20 | % {[char]$_})
$ContainerName = "scripts"

New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Location $LocationName -Name $StorageAccountName -Kind Storage -SkuName Standard_GRS
$sacc = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$url = "https://$StorageAccountName.blob.core.windows.net"

Set-AzureRmCurrentStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName
New-AzureStorageContainer -Name $ContainerName -Permission Blob

Set-AzureStorageBlobContent -Container $ContainerName -File $ScriptToUpload

Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -StorageAccountName $StorageAccountName -ContainerName "scripts" -FileName $RunFileName -Run $RunFileName -Name $ScriptExtensionName -Location $LocationName

# Clean up
Remove-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $ScriptExtensionName -Force
Remove-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Force