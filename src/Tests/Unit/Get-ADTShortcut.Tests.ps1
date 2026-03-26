BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force

    # Create a .lnk shortcut in TestDrive using WScript.Shell COM.
    $script:LnkPath = Join-Path $TestDrive 'test.lnk'
    $WshShell = [System.Activator]::CreateInstance([System.Type]::GetTypeFromProgID('WScript.Shell'))
    $shortcut = $WshShell.CreateShortcut($script:LnkPath)
    $shortcut.TargetPath = "$env:SystemRoot\System32\cmd.exe"
    $shortcut.Arguments = '/k dir'
    $shortcut.Description = 'Test shortcut description'
    $shortcut.WorkingDirectory = "$env:SystemRoot\System32"
    $shortcut.WindowStyle = 1   # Normal
    $shortcut.Save()

    # Create a .url shortcut in TestDrive as a plain text file.
    $script:UrlPath = Join-Path $TestDrive 'test.url'
    Set-Content -Path $script:UrlPath -Value @(
        '[InternetShortcut]',
        'URL=https://psappdeploytoolkit.com',
        'IconFile=C:\Windows\System32\url.dll',
        'IconIndex=0'
    )
}

Describe 'Get-ADTShortcut' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }
    }

    Context '.lnk Shortcut' {
        It 'Returns a ShellLinkInfo object' {
            Get-ADTShortcut -LiteralPath $script:LnkPath | Should -BeOfType ([PSADT.ShortcutManagement.ShellLinkInfo])
        }

        It 'TargetPath matches the path set when creating the shortcut' {
            $result = Get-ADTShortcut -LiteralPath $script:LnkPath
            $result.TargetPath | Should -Be "$env:SystemRoot\System32\cmd.exe"
        }

        It 'Arguments matches the arguments set when creating the shortcut' {
            $result = Get-ADTShortcut -LiteralPath $script:LnkPath
            $result.Arguments | Should -Be '/k dir'
        }

        It 'Description matches the description set when creating the shortcut' {
            $result = Get-ADTShortcut -LiteralPath $script:LnkPath
            $result.Description | Should -Be 'Test shortcut description'
        }

        It 'WorkingDirectory matches the working directory set when creating the shortcut' {
            $result = Get-ADTShortcut -LiteralPath $script:LnkPath
            $result.WorkingDirectory | Should -Be "$env:SystemRoot\System32"
        }

        It 'WindowStyle is Normal for a shortcut created with style 1' {
            $result = Get-ADTShortcut -LiteralPath $script:LnkPath
            $result.WindowStyle | Should -Be 'Normal'
        }

        It 'RunAsAdmin is false for a shortcut without the elevated flag' {
            $result = Get-ADTShortcut -LiteralPath $script:LnkPath
            $result.RunAsAdmin | Should -BeFalse
        }

        It 'Does not throw for a valid .lnk file' {
            { Get-ADTShortcut -LiteralPath $script:LnkPath } | Should -Not -Throw
        }
    }

    Context '.url Shortcut' {
        It 'Returns an InternetShortcutInfo object' {
            Get-ADTShortcut -LiteralPath $script:UrlPath | Should -BeOfType ([PSADT.ShortcutManagement.InternetShortcutInfo])
        }

        It 'Url contains the URL from the .url file' {
            $result = Get-ADTShortcut -LiteralPath $script:UrlPath
            $result.Url.OriginalString | Should -Be 'https://psappdeploytoolkit.com'
        }

        It 'Does not throw for a valid .url file' {
            { Get-ADTShortcut -LiteralPath $script:UrlPath } | Should -Not -Throw
        }
    }

    Context 'Input Validation' {
        It 'Throws for a path with a non-shortcut extension' {
            $txtPath = Join-Path $TestDrive 'file.txt'
            Set-Content -Path $txtPath -Value 'not a shortcut'
            { Get-ADTShortcut -LiteralPath $txtPath } | Should -Throw
        }

        It 'Throws for a path that does not exist' {
            { Get-ADTShortcut -LiteralPath (Join-Path $TestDrive 'nonexistent.lnk') } | Should -Throw
        }
    }
}
