BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force
}

Describe 'Stop-ADTServiceAndDependencies' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }
        Mock -ModuleName PSAppDeployToolkit Invoke-ADTServiceAndDependencyOperation { }

        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'SpoolerService', Justification = 'Used in It blocks within the InputObject Context.')]
        $SpoolerService = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
    }

    Context 'WhatIf suppresses the operation' {
        It 'Does not call Invoke-ADTServiceAndDependencyOperation when -WhatIf is specified' {
            Stop-ADTServiceAndDependencies -Name 'Spooler' -WhatIf
            Should -Not -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Scope It
        }

        It 'Does not throw when -WhatIf is specified' {
            { Stop-ADTServiceAndDependencies -Name 'Spooler' -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Name parameter set' {
        It 'Does not throw for a valid service name' {
            { Stop-ADTServiceAndDependencies -Name 'Spooler' } | Should -Not -Throw
        }

        It 'Calls Invoke-ADTServiceAndDependencyOperation exactly once' {
            Stop-ADTServiceAndDependencies -Name 'Spooler'
            Should -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Times 1 -Exactly -Scope It
        }

        It 'Passes -Operation Stop to the inner operation' {
            Stop-ADTServiceAndDependencies -Name 'Spooler'
            Should -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Scope It `
                -ParameterFilter { $Operation -eq 'Stop' }
        }

        It 'Passes -PassThru to the inner operation when specified' {
            Stop-ADTServiceAndDependencies -Name 'Spooler' -PassThru
            Should -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Scope It `
                -ParameterFilter { $PassThru -eq $true }
        }

        It 'Passes -SkipDependentServices to the inner operation when specified' {
            Stop-ADTServiceAndDependencies -Name 'Spooler' -SkipDependentServices
            Should -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Scope It `
                -ParameterFilter { $SkipDependentServices -eq $true }
        }

        It 'Passes -PendingStatusWait to the inner operation when specified' {
            $wait = [System.TimeSpan]::FromSeconds(30)
            Stop-ADTServiceAndDependencies -Name 'Spooler' -PendingStatusWait $wait
            Should -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Scope It `
                -ParameterFilter { $PendingStatusWait -eq [System.TimeSpan]::FromSeconds(30) }
        }
    }

    Context 'InputObject parameter set' {
        It 'Does not throw with a valid ServiceController and -WhatIf' {
            if (-not $SpoolerService) { Set-ItResult -Skipped -Because 'Spooler service not found on this machine'; return }
            { Stop-ADTServiceAndDependencies -InputObject $SpoolerService -WhatIf } | Should -Not -Throw
        }

        It 'Does not call the operation for InputObject with -WhatIf' {
            if (-not $SpoolerService) { Set-ItResult -Skipped -Because 'Spooler service not found on this machine'; return }
            Stop-ADTServiceAndDependencies -InputObject $SpoolerService -WhatIf
            Should -Not -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Scope It
        }

        It 'Calls the operation for a valid ServiceController without -WhatIf' {
            if (-not $SpoolerService) { Set-ItResult -Skipped -Because 'Spooler service not found on this machine'; return }
            Stop-ADTServiceAndDependencies -InputObject $SpoolerService
            Should -Invoke Invoke-ADTServiceAndDependencyOperation -ModuleName PSAppDeployToolkit -Times 1 -Exactly -Scope It
        }
    }

    Context 'Input validation' {
        It 'Throws when -Name is an empty string' {
            { Stop-ADTServiceAndDependencies -Name '' } | Should -Throw
        }
    }
}
