BeforeAll {
    Import-Module "$PSScriptRoot\..\Support\PSAppDeployToolkit.TestHelpers.psm1"
    Import-ADTModuleUnderTest

    # Mock Write-ADTLogEntry due to its expense when running via Pester.
    Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }

    function Test-PhysicalInterfaceIsUp
    {
        param
        (
            [Parameter(Mandatory = $true)]
            [System.Net.NetworkInformation.NetworkInterfaceType[]]$InterfaceType
        )

        # CIM identifies visible physical adapters; .NET independently reports their type and link
        # status. Virtual Ethernet interfaces can be Up even when every physical wired adapter is down.
        $physicalIds = @(Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetAdapter -Filter 'HardwareInterface=True AND Hidden=False' | Select-Object -ExpandProperty InterfaceGuid)
        foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces())
        {
            if (($nic.Id -in $physicalIds) -and ($nic.NetworkInterfaceType -in $InterfaceType) -and ($nic.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up))
            {
                return $true
            }
        }
        return $false
    }
}

Describe 'Test-ADTNetworkConnection' {
    Context 'Functionality' {
        It 'Returns a boolean' {
            Test-ADTNetworkConnection | Should -BeOfType ([System.Boolean])
        }

        It 'Agrees with the physical interfaces Windows reports' {
            # The default is physical wired or wireless, so the oracle cross-checks that pair via CIM and .NET.
            Test-ADTNetworkConnection | Should -Be (Test-PhysicalInterfaceIsUp -InterfaceType Ethernet, Wireless80211)
        }

        It 'Narrows to the interface types it is given' {
            Test-ADTNetworkConnection -InterfaceType Ethernet | Should -Be (Test-PhysicalInterfaceIsUp -InterfaceType Ethernet)
        }

        It 'Reports false for a type this machine has no connected adapter of' {
            # Token ring is a safe stand-in for absent hardware.
            Test-ADTNetworkConnection -InterfaceType TokenRing | Should -BeFalse
        }

        It 'Rejects a repeated interface type' {
            { Test-ADTNetworkConnection -InterfaceType Ethernet, Ethernet } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
        }

        It 'Rejects an interface type that does not exist' {
            { Test-ADTNetworkConnection -InterfaceType 'NotAnInterfaceType' } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
        }
    }

    Context 'Physical adapter selection' {
        BeforeEach {
            # Disconnected Ethernet and connected Wi-Fi distinguish type filtering from simply asking
            # whether any adapter is Up, independently of the host machine's current network state.
            Mock -ModuleName PSAppDeployToolkit Get-NetAdapter {
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Disconnected'; InterfaceType = [System.UInt32]6 }
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Up'; InterfaceType = [System.UInt32]71 }
            }
        }

        It 'Reports <Expected> when the selected types are <Name>' -ForEach @(
            @{ Name = 'Ethernet'; InterfaceType = @('Ethernet'); Expected = $false }
            @{ Name = 'Wi-Fi'; InterfaceType = @('Wireless80211'); Expected = $true }
            @{ Name = 'Ethernet and Wi-Fi'; InterfaceType = @('Ethernet', 'Wireless80211'); Expected = $true }
            @{ Name = 'an absent type'; InterfaceType = @('TokenRing'); Expected = $false }
        ) {
            Test-ADTNetworkConnection -InterfaceType $InterfaceType | Should -Be $Expected
        }

        It 'Detects a connected physical Ethernet adapter when Ethernet alone is selected' {
            Mock -ModuleName PSAppDeployToolkit Get-NetAdapter {
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Up'; InterfaceType = [System.UInt32]6 }
            }
            Test-ADTNetworkConnection -InterfaceType Ethernet | Should -BeTrue
        }

        It 'Reports false when no physical adapter is connected' {
            Mock -ModuleName PSAppDeployToolkit Get-NetAdapter {
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Disconnected'; InterfaceType = [System.UInt32]6 }
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Disconnected'; InterfaceType = [System.UInt32]71 }
            }
            Test-ADTNetworkConnection | Should -BeFalse
        }

        It 'Reports false when there are no physical adapters' {
            Mock -ModuleName PSAppDeployToolkit Get-NetAdapter { }
            Test-ADTNetworkConnection | Should -BeFalse
        }

        It 'Excludes connected virtual Ethernet adapters' {
            # Without -Physical the boundary would return an Up virtual Ethernet adapter. With it,
            # only the disconnected physical adapter is returned, reproducing the original failure's
            # topology without depending on Hyper-V being installed on the machine running the tests.
            Mock -ModuleName PSAppDeployToolkit Get-NetAdapter {
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Up'; InterfaceType = [System.UInt32]6 }
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Disconnected'; InterfaceType = [System.UInt32]6 }
            }
            Mock -ModuleName PSAppDeployToolkit Get-NetAdapter {
                New-Object -TypeName System.Management.Automation.PSObject -Property @{ Status = 'Disconnected'; InterfaceType = [System.UInt32]6 }
            } -ParameterFilter { $Physical }

            Test-ADTNetworkConnection -InterfaceType Ethernet | Should -BeFalse
            Should -Invoke -ModuleName PSAppDeployToolkit Get-NetAdapter -Times 1 -Exactly -ParameterFilter { $Physical }
        }
    }
}
