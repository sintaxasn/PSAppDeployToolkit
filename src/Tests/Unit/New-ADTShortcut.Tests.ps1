BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force
}

Describe 'New-ADTShortcut' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }

        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'LnkPath', Justification = "Variable is used within It scriptblocks.")]
        $script:LnkPath = $null

        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'UrlPath', Justification = "Variable is used within It scriptblocks.")]
        $script:UrlPath = $null
    }

    BeforeEach {
        $testDir = Join-Path $TestDrive (New-Guid)
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
        $script:LnkPath = Join-Path $testDir 'TestShortcut.lnk'
        $script:UrlPath = Join-Path $testDir 'TestShortcut.url'
    }

    Context 'LNK creation' {
        It 'Creates a .lnk file with required parameters' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe'
            Test-Path -LiteralPath $script:LnkPath | Should -BeTrue
        }

        It 'Does not throw when creating a valid .lnk' {
            { New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe' } | Should -Not -Throw
        }

        It 'Shortcut TargetPath is set correctly' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe'
            $sc = Get-ADTShortcut -LiteralPath $script:LnkPath
            $sc.TargetPath | Should -Be 'C:\Windows\System32\cmd.exe'
        }

        It 'Shortcut Description is set when provided' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe' -Description 'Test Desc'
            $sc = Get-ADTShortcut -LiteralPath $script:LnkPath
            $sc.Description | Should -Be 'Test Desc'
        }

        It 'Shortcut WorkingDirectory is set when provided' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe' -WorkingDirectory 'C:\Windows'
            $sc = Get-ADTShortcut -LiteralPath $script:LnkPath
            $sc.WorkingDirectory | Should -Be 'C:\Windows'
        }

        It 'WindowStyle Maximized sets shortcut window style' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe' -WindowStyle Maximized
            $sc = Get-ADTShortcut -LiteralPath $script:LnkPath
            $sc.WindowStyle | Should -Be 3
        }

        It 'RunAsAdmin sets byte 21 of the .lnk file' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe' -RunAsAdmin
            $bytes = [System.IO.File]::ReadAllBytes($script:LnkPath)
            ($bytes[21] -band 32) | Should -Be 32
        }

        It 'Overwrites an existing shortcut without throwing' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe'
            { New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\notepad.exe' -Force } | Should -Not -Throw
            $sc = Get-ADTShortcut -LiteralPath $script:LnkPath
            $sc.TargetPath | Should -Be 'C:\Windows\notepad.exe'
        }

        It 'Creates parent directory if it does not exist' {
            $deepLnk = Join-Path -Path (Join-Path -Path (Join-Path -Path $TestDrive -ChildPath (New-Guid)) -ChildPath 'SubDir') -ChildPath 'deep.lnk'
            New-ADTShortcut -LiteralPath $deepLnk -TargetPath 'C:\Windows\System32\cmd.exe' -Force
            Test-Path -LiteralPath $deepLnk | Should -BeTrue
        }
    }

    Context 'URL creation' {
        It 'Creates a .url file with required parameters' {
            New-ADTShortcut -LiteralPath $script:UrlPath -TargetPath 'https://psappdeploytoolkit.com'
            Test-Path -LiteralPath $script:UrlPath | Should -BeTrue
        }

        It '.url file contains correct URL line' {
            # Use a URL with an explicit path to avoid System.Uri trailing-slash normalisation.
            New-ADTShortcut -LiteralPath $script:UrlPath -TargetPath 'https://psappdeploytoolkit.com/home'
            $content = [System.IO.File]::ReadAllLines($script:UrlPath)
            $content | Should -Contain 'URL=https://psappdeploytoolkit.com/home'
        }

        It '.url file contains [InternetShortcut] header' {
            New-ADTShortcut -LiteralPath $script:UrlPath -TargetPath 'https://psappdeploytoolkit.com'
            $content = [System.IO.File]::ReadAllLines($script:UrlPath)
            $content | Should -Contain '[InternetShortcut]'
        }

        It '.url file includes IconFile line when IconLocation provided' {
            New-ADTShortcut -LiteralPath $script:UrlPath -TargetPath 'https://psappdeploytoolkit.com' -IconLocation 'C:\Windows\System32\cmd.exe'
            $content = [System.IO.File]::ReadAllLines($script:UrlPath)
            $iconLine = $content | Where-Object { $_.StartsWith('IconFile=') }
            $iconLine | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Validation' {
        It 'Throws a terminating error for an invalid extension (.txt)' {
            { New-ADTShortcut -LiteralPath (Join-Path $TestDrive 'bad.txt') -TargetPath 'C:\Windows\notepad.exe' } | Should -Throw
        }

        It 'Throws a terminating error for an extension-less path' {
            { New-ADTShortcut -LiteralPath (Join-Path $TestDrive 'noextension') -TargetPath 'C:\Windows\notepad.exe' } | Should -Throw
        }
    }

    Context 'WhatIf' {
        It '-WhatIf does not create the .lnk file' {
            New-ADTShortcut -LiteralPath $script:LnkPath -TargetPath 'C:\Windows\System32\cmd.exe' -WhatIf
            Test-Path -LiteralPath $script:LnkPath | Should -BeFalse
        }

        It '-WhatIf does not create the .url file' {
            New-ADTShortcut -LiteralPath $script:UrlPath -TargetPath 'https://psappdeploytoolkit.com' -WhatIf
            Test-Path -LiteralPath $script:UrlPath | Should -BeFalse
        }
    }
}
