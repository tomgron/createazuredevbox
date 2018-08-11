[Reflection.Assembly]::LoadWithPartialName("System.Web")

$LocationName = "North Europe"
$ResourceGroupName = "DevBox-$(get-date -f yyyy-MM-dd)"
$Random = -join ((97..122) | Get-Random -Count 5 | % {[char]$_})

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

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name NetworkSecurityGroupRuleRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
$nsgRulePSR = New-AzureRmNetworkSecurityRuleConfig -Name NetworkSecurityGroupRulePRS  -Protocol * -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Access Allow
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -Name NSG -SecurityRules $nsgRuleRDP,$nsgRulePSR

# Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name NetworkSecurityGroupRuleRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
# Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name NetworkSecurityGroupRulePSR  -Protocol * -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Access Allow

# setup vm networking
$SingleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzureRmVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
$PIP = New-AzureRmPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
$NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id -Primary 
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

# Download RemoteInstall.ps1 from gist
Write "Download latest RemoteInstall.ps1 from GitHub"
#Invoke-WebRequest https://gist.githubusercontent.com/tomgron/5309d64c0cc07eb1cac9f048513d9dc3/raw/0a5aacfda61a647708e09f6736ed5c928a1d41f5/install.cmd -OutFile .\RemoteInstall.ps1

write "Upload RemoteInstall.ps1 to server and start installation - this will take a lot of time..."
Copy-Item -Path .\RemoteInstall.ps1 -Destination c:\RemoteInstall.ps1 -ToSession $session

# Run the actual command file
Invoke-Command -Session $session { c:\RemoteInstall.ps1 }

#Optional - shut down the VM to save costs
Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force

#output necessary info
Write-Host "DNS of server: $DNSNameLabel.northeurope.cloudapp.azure.com for RDP connections"
Write-Host "IP of server : $addr"
Write-Host "Username : $addr\LocalAdminUser, Password : $VMLocalClearTextPassword"
