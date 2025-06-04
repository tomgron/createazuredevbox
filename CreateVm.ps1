    $LocationName = "North Europe"
    $Random = -join ((97..122) | Get-Random -Count 12 | % {[char]$_})
    $ResourceGroupName = "DevBox-$($Random)"

    if ((Get-AzContext) -eq $null) { Login-AzAccount }

    $sub = Get-AzSubscription -SubscriptionName "Pay-As-You-Go" | Select-AzSubscription

    Remove-AzResourceGroup -Name $ResourceGroupName -Force -ErrorAction SilentlyContinue
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName -Force
    $rg = Get-AzResourceGroup -Name $ResourceGroupName

    # Credentials for Local Admin account you created in the sysprepped (generalized) vhd image
    $VMLocalAdminUser = "LocalAdminUser"
    $VMLocalClearTextPassword = ([char[]]([char]65..[char]90) + ([char[]]([char]97..[char]122)) + 0..9 | sort {Get-Random})[0..12] -join ''
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
    $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name NetworkSecurityGroupRuleRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
    $nsgRulePSR = New-AzNetworkSecurityRuleConfig -Name NetworkSecurityGroupRulePRS  -Protocol * -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Access Allow
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -Name NSG -SecurityRules $nsgRuleRDP,$nsgRulePSR

    # Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name NetworkSecurityGroupRuleRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
    # Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name NetworkSecurityGroupRulePSR  -Protocol * -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Access Allow

    # setup vm networking
    $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
    $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
    $PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id

    $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id -Primary 
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter-with-Containers' -Version latest
    $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

    Write-Host "Creating VM"
    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose

    Write-Host "DNS of server: $DNSNameLabel.northeurope.cloudapp.azure.com for RDP connections" >> username.txt
    Write-Host "Username : $addr\LocalAdminUser, Password : $VMLocalClearTextPassword" >> username.txt

    # Enable VM to shut down automatically
    Write-Host "Enabling autoshutdown"
    .\Set-AzVMAutoShutdown.ps1 -ResourceGroupName $ResourceGroupName -Name $VMName -Enable -Time "19:00:00" -TimeZone "UTC"

    # Enable ps remoting
    Write-Host "Enabling PS remoting"
    .\UploadScripts.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -LocationName $LocationName -ScriptToUpload .\EnablePsRemotingOnVM.ps1 -RunFileName "EnablePsRemotingOnVM.ps1" -ScriptExtensionName "EnableRemoting"

    # Expand OS disk - first stop VM
    Write-Host "Stopping VM for disk resize"
    Stop-AzVm -ResourceGroupName $ResourceGroupName -Name $VMName -Force

    Write-Host "Resizing disk from 127GB top 256GB"
    $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $VirtualMachine.StorageProfile.OsDisk.Name
    $disk.DiskSizeGB = 256
    Update-AzDisk -ResourceGroupName $ResourceGroupName -Disk $disk -DiskName $disk.Name
    
    Write-Host "Starting Azure VM"
    Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

    Write-Host "Resizing logical volume C:"
    .\UploadScripts.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -ScriptToUpload .\RemoteResizeVolume.ps1 -RunFileName RemoteResizeVolume.ps1 -ScriptExtensionName "ResizeVolume" -LocationName $LocationName
    
    Write-Host "Setting Local Network Connection Profile to work with remote VMs" -ForegroundColor Yellow
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

    Write-Host "Enabling PS remoting locally"
    Enable-PSRemoting -SkipNetworkProfileCheck -Confirm:$false -Force
    Enable-WSManCredSSP -role Client -delegatecomputer "*.northeurope.cloudapp.azure.com" -Force
    $addr = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName | select ipaddress).IpAddress.ToString()
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

    # write "Upload RemoteInstall.ps1 to server and start installation - this will take a lot of time..."
    Copy-Item -Path .\RemoteInstall.ps1 -Destination c:\RemoteInstall.ps1 -ToSession $session

    # Run the actual command file
    Invoke-Command -Session $session { c:\RemoteInstall.ps1 }

    # #Optional - shut down the VM to save costs
    Write-Host "Shutting down VM to cut costs"
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force

#output necessary info
Write-Host "DNS of server: $DNSNameLabel.northeurope.cloudapp.azure.com for RDP connections"
Write-Host "IP of server : $addr"
Write-Host "Username : $addr\LocalAdminUser, Password : $VMLocalClearTextPassword"

