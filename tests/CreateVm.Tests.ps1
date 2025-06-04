Describe 'CreateVm script' {
    BeforeAll {
        $azCommands = @(
            'Add-AzNetworkSecurityRuleConfig',
            'Add-AzVMNetworkInterface',
            'Get-AzContext',
            'Get-AzDisk',
            'Get-AzPublicIpAddress',
            'Get-AzResourceGroup',
            'Get-AzSubscription',
            'Login-AzAccount',
            'New-AzNetworkInterface',
            'New-AzNetworkSecurityGroup',
            'New-AzNetworkSecurityRuleConfig',
            'New-AzPublicIpAddress',
            'New-AzResourceGroup',
            'New-AzVM',
            'New-AzVMConfig',
            'New-AzVirtualNetwork',
            'New-AzVirtualNetworkSubnetConfig',
            'Remove-AzResourceGroup',
            'Select-AzSubscription',
            'Set-AzVMAutoShutdown',
            'Set-AzVMBootDiagnostic',
            'Set-AzVMOperatingSystem',
            'Set-AzVMSourceImage',
            'Start-AzVM',
            'Stop-AzVM',
            'Update-AzDisk'
        )
        foreach ($cmd in $azCommands) {
            Mock -CommandName $cmd -MockWith {}
        }
    }

    It 'runs without syntax errors' {
        $script = Join-Path $PSScriptRoot '..' 'CreateVm.ps1'
        powershell -NoProfile -Command "& { . '$script' }" | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
