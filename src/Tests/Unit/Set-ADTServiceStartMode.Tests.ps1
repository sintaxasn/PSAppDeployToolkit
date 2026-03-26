BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force

    $script:SpoolerSvc = Get-Service -Name 'Spooler'
}

Describe 'Set-ADTServiceStartMode' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }
    }

    Context '-WhatIf prevents sc.exe invocation' {
        It 'Does not throw with -WhatIf and StartMode Automatic' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'Automatic' -WhatIf } | Should -Not -Throw
        }

        It 'Does not throw with -WhatIf and StartMode Manual' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'Manual' -WhatIf } | Should -Not -Throw
        }

        It 'Does not throw with -WhatIf and StartMode Disabled' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'Disabled' -WhatIf } | Should -Not -Throw
        }

        It 'Does not throw with -WhatIf and StartMode Automatic (Delayed Start)' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'Automatic (Delayed Start)' -WhatIf } | Should -Not -Throw
        }

        It 'Does not throw with -WhatIf and StartMode Boot' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'Boot' -WhatIf } | Should -Not -Throw
        }

        It 'Does not throw with -WhatIf and StartMode System' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'System' -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Input validation' {
        It 'Throws for a StartMode value not in the ValidateSet' {
            { Set-ADTServiceStartMode -Service $script:SpoolerSvc -StartMode 'InvalidMode' -WhatIf } | Should -Throw
        }
    }
}
