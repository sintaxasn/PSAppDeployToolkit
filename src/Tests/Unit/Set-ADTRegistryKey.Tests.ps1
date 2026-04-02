BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force

    $script:TestKeyBase = "HKCU:\SOFTWARE\PSADTTest_$([System.Guid]::NewGuid().ToString('N'))"
    $null = New-Item -Path $script:TestKeyBase -Force
}

AfterAll {
    Remove-Item -LiteralPath $script:TestKeyBase -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Set-ADTRegistryKey' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }

        # Set-ADTRegistryKey calls Convert-ADTRegistryPath internally, which references
        # [PSADT.AccountManagement.AccountUtilities]::CallerSid at compile time.
        # PowerShell resolves all type literals at compile time, requiring admin rights.
        $script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    BeforeEach {
        if (!$script:IsAdmin) { Set-ItResult -Skipped -Because 'Requires admin rights (AccountUtilities static constructor triggered at compile time)'; return }
        $script:TestKey = "$script:TestKeyBase\$([System.Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $script:TestKey -Force
    }

    AfterEach {
        if ($script:TestKey) { Remove-Item -LiteralPath $script:TestKey -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Key-only creation' {
        It 'Does not throw when called with only -LiteralPath for an existing key' {
            { Set-ADTRegistryKey -LiteralPath $script:TestKey } | Should -Not -Throw
        }

        It 'Creates a new registry key when it does not exist' {
            $newKey = "$script:TestKeyBase\$([System.Guid]::NewGuid().ToString('N'))"
            Set-ADTRegistryKey -LiteralPath $newKey
            $exists = Test-Path -LiteralPath $newKey
            Remove-Item -LiteralPath $newKey -Force -ErrorAction SilentlyContinue
            $exists | Should -BeTrue
        }

        It 'Does not throw when key already exists and no -Name is given' {
            { Set-ADTRegistryKey -LiteralPath $script:TestKey } | Should -Not -Throw
        }
    }

    Context 'String value' {
        It 'Does not throw when setting a String value' {
            { Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'StrVal' -Value 'Hello' -Type String } | Should -Not -Throw
        }

        It 'Sets a String value that can be read back' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'StrVal' -Value 'Hello' -Type String
            Get-ItemPropertyValue -LiteralPath $script:TestKey -Name 'StrVal' | Should -Be 'Hello'
        }

        It 'Updates an existing String value' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'StrVal' -Value 'First' -Type String
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'StrVal' -Value 'Second' -Type String
            Get-ItemPropertyValue -LiteralPath $script:TestKey -Name 'StrVal' | Should -Be 'Second'
        }
    }

    Context 'DWord value' {
        It 'Does not throw when setting a DWord value' {
            { Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'DwVal' -Value 42 -Type DWord } | Should -Not -Throw
        }

        It 'Sets a DWord value that can be read back' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'DwVal' -Value 42 -Type DWord
            Get-ItemPropertyValue -LiteralPath $script:TestKey -Name 'DwVal' | Should -Be 42
        }
    }

    Context 'MultiString value — MultiStringValueMode' {
        It 'Sets a MultiString value with Replace mode (default)' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'MsVal' -Value @('Alpha', 'Beta') -Type MultiString
            $result = Get-ItemPropertyValue -LiteralPath $script:TestKey -Name 'MsVal'
            $result | Should -Contain 'Alpha'
            $result | Should -Contain 'Beta'
        }

        It 'Adds new entries with Add mode and does not duplicate existing entries' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'MsVal' -Value @('A', 'B') -Type MultiString
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'MsVal' -Value @('B', 'C') -Type MultiString -MultiStringValueMode Add
            $result = Get-ItemPropertyValue -LiteralPath $script:TestKey -Name 'MsVal'
            $result | Should -Contain 'A'
            $result | Should -Contain 'B'
            $result | Should -Contain 'C'
            @($result | Where-Object { $_ -eq 'B' }).Count | Should -Be 1
        }

        It 'Removes specific entries with Remove mode' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'MsVal' -Value @('A', 'B', 'C') -Type MultiString
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'MsVal' -Value @('B') -Type MultiString -MultiStringValueMode Remove
            $result = Get-ItemPropertyValue -LiteralPath $script:TestKey -Name 'MsVal'
            $result | Should -Contain 'A'
            $result | Should -Not -Contain 'B'
            $result | Should -Contain 'C'
        }
    }

    Context '-WhatIf' {
        It 'Does not create the key when -WhatIf is specified' {
            $newKey = "$script:TestKeyBase\$([System.Guid]::NewGuid().ToString('N'))"
            Set-ADTRegistryKey -LiteralPath $newKey -WhatIf
            Test-Path -LiteralPath $newKey | Should -BeFalse
        }

        It 'Does not set a value when -WhatIf is specified' {
            Set-ADTRegistryKey -LiteralPath $script:TestKey -Name 'WiVal' -Value 'nope' -Type String -WhatIf
            $props = (Get-ItemProperty -LiteralPath $script:TestKey -ErrorAction SilentlyContinue).PSObject.Properties | Select-Object -ExpandProperty Name
            $props | Should -Not -Contain 'WiVal'
        }
    }
}
