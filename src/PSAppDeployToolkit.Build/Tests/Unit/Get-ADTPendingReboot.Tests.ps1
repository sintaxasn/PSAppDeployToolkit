BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force
}
Describe 'Get-ADTPendingReboot' {
    BeforeAll {
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }
    }

    Context 'Functionality' {
        It 'Should not throw' {
            { Get-ADTPendingReboot } | Should -Not -Throw
        }

        It 'Should return an object of type PSADT.DeviceManagement.RebootInfo' {
            $result = Get-ADTPendingReboot
            $result | Should -BeOfType ([PSADT.DeviceManagement.RebootInfo])
        }

        It 'Should return a non-empty ComputerName' {
            $result = Get-ADTPendingReboot
            $result.ComputerName | Should -Not -BeNullOrEmpty
        }

        It 'Should return a ComputerName matching the current host' {
            $result = Get-ADTPendingReboot
            $result.ComputerName | Should -Be ([System.Net.Dns]::GetHostName())
        }

        It 'Should return a LastBootUpTime that is in the past' {
            $result = Get-ADTPendingReboot
            $result.LastBootUpTime | Should -BeLessThan ([System.DateTime]::Now)
        }

        It 'Should return a Boolean IsSystemRebootPending' {
            $result = Get-ADTPendingReboot
            $result.IsSystemRebootPending | Should -BeOfType ([System.Boolean])
        }

        It 'Should return a Boolean IsCBServicingRebootPending' {
            $result = Get-ADTPendingReboot
            $result.IsCBServicingRebootPending | Should -BeOfType ([System.Boolean])
        }

        It 'Should return a Boolean IsWindowsUpdateRebootPending' {
            $result = Get-ADTPendingReboot
            $result.IsWindowsUpdateRebootPending | Should -BeOfType ([System.Boolean])
        }

        It 'Should return a Boolean IsAppVRebootPending' {
            $result = Get-ADTPendingReboot
            $result.IsAppVRebootPending | Should -BeOfType ([System.Boolean])
        }

        It 'Should return an ErrorMsg collection (empty when no errors occurred)' {
            $result = Get-ADTPendingReboot
            $null -ne $result.ErrorMsg | Should -BeTrue
        }

        It 'Should expose a PendingFileRenameOperations member' {
            # The value is legitimately null on a machine with no pending file renames, so only
            # assert the member's presence on the returned object.
            $result = Get-ADTPendingReboot
            $result.PSObject.Properties.Name | Should -Contain 'PendingFileRenameOperations'
        }

        It 'Nullable reboot flags are null or boolean' {
            $result = Get-ADTPendingReboot
            foreach ($p in 'IsSCCMClientRebootPending', 'IsIntuneClientRebootPending', 'IsFileRenameRebootPending')
            {
                ($null -eq $result.$p -or $result.$p -is [System.Boolean]) | Should -BeTrue
            }
        }
    }

    Context 'Metadata' {
        It 'Should declare OutputType of PSADT.DeviceManagement.RebootInfo' {
            $outputTypes = (Get-Command Get-ADTPendingReboot).OutputType.Type
            $outputTypes | Should -Contain ([PSADT.DeviceManagement.RebootInfo])
        }
    }
}
