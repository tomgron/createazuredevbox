[Reflection.Assembly]::LoadWithPartialName("System.Web")

$LocationName = "North Europe"
$ResourceGroupName = "DevBox-$(get-date -f yyyy-MM-dd)"
$Random = -join ((97..122) | Get-Random -Count 20 | % {[char]$_})

if ((Get-AzureRmContext) -eq $null) { Login-AzureRmAccount }

$sub = Get-AzureRmSubscription | Where-Object Name -EQ "Pay-As-You-Go" 

Select-AzureRmSubscription -SubscriptionObject $sub

Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force -ErrorAction SilentlyContinue
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LocationName -Force
$rg = Get-AzureRmResourceGroup -Name $ResourceGroupName

# Credentials for Local Admin account you created in the sysprepped (generalized) vhd image
$VMLocalAdminUser = "LocalAdminUser"
$VMLocalClearTextPassword = [System.Web.Security.Membership]::GeneratePassword(11,0)
$VMLocalAdminSecurePassword = ConvertTo-SecureString $VMLocalClearTextPassword -AsPlainText -Force

# ## VM
$ComputerName = "DevBox"
$VMName = "DevBox"
# # Modern hardware environment with fast disk, high IOPs performance.
# # Required to run a client VM with efficiency and performance
$VMSize = "Standard_DS3"

# ## Networking
$DNSNameLabel = "devbox-$Random" # mydnsname.westus.cloudapp.azure.com
$NetworkName = "MyNet"
$NICName = "MyNIC"
$PublicIPAddressName = "MyPIP"
$SubnetName = "MySubnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"

$SingleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzureRmVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
$PIP = New-AzureRmPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
$NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter-with-Containers' -Version latest
$VirtualMachine = Set-AzureRmVMBootDiagnostics -VM $VirtualMachine -Disable

write "Creating VM"
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose

# Enable VM to shut down automatically
write "Enabling autoshutdown"
.\Set-AzureRmVMAutoShutdown.ps1 -ResourceGroupName $ResourceGroupName -Name $VMName -Enable -Time "19:00:00" -TimeZone "UTC"

# Enable ps remoting
write "Enabling PS remoting"
.\UploadScripts.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -LocationName $LocationName -ScriptToUpload .\EnablePsRemotingOnVM.ps1 -RunFileName "EnablePsRemotingOnVM.ps1" -ScriptExtensionName "EnableRemoting"

write "Setting Network Connection Profile" -ForegroundColor Yellow
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

write "Enabling PS remoting locally"
Enable-PSRemoting -SkipNetworkProfileCheck -Confirm:$false -Force
Enable-WSManCredSSP -role Client -delegatecomputer "*.northeurope.cloudapp.azure.com" -Force
$addr = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName | select ipaddress).IpAddress.ToString()
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $addr -Force -Confirm:$false # Set ip to trusted hosts

try {
    $LocalAdminUser = "$addr\"+$VMLocalAdminUser
    $LocalAdminCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($LocalAdminUser, $VMLocalAdminSecurePassword)

    $uri = "https://"+$addr+":5986"

    Write-Host "Connecting PSSession to URI $uri"

    $session = New-PSSession -ConnectionUri $uri -Credential $LocalAdminCred -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -Authentication Negotiate

    Write-Host "Connected"
}
catch {
    Write-Host ERROR -BackgroundColor Red -ForegroundColor White
}

#output necessary info
Write-Host "IP of server : $addr for RDP connections"
Write-Host "Username : LocalAdminUser, Password : $VMLocalClearTextPassword"