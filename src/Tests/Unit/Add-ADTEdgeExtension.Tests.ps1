BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force
}
Describe 'Add-ADTEdgeExtension' {
    BeforeAll {
        # Mock Convert-ADTRegistryPath to redirect registry paths to TestRegistry:\
        # Inline the path normalization to avoid calling the real function (which triggers
        # PSADT.AccountManagement.AccountUtilities static constructor requiring admin rights).
        Mock -ModuleName PSAppDeployToolkit Convert-ADTRegistryPath {
            param([string]$Key, [string]$SID, [switch]$Wow6432Node)
            $null = $SID, $Wow6432Node
            $testRegistryRoot = (Get-PSDrive -Name TestRegistry).Root
            $normalizedKey = $Key -replace '^.+::' `
                -replace '^HKLM:?\\', 'HKEY_LOCAL_MACHINE\' `
                -replace '^HKCU:?\\', 'HKEY_CURRENT_USER\' `
                -replace '^HKCR:?\\', 'HKEY_CLASSES_ROOT\' `
                -replace '^HKU:?\\', 'HKEY_USERS\' `
                -replace '^HKCC:?\\', 'HKEY_CURRENT_CONFIG\'
            return "Microsoft.PowerShell.Core\Registry::$testRegistryRoot\$normalizedKey"
        }

        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables {}
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }

        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'RedirectedEdgeKey', Justification = "This variable is used within scriptblocks that PSScriptAnalyzer has no visibility of.")]
        $RedirectedEdgeKey = 'TestRegistry:\HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge'
    }

    Context 'Functionality' {
        It 'Should add an extension to a non-existent registry key' {
            $extensionId = 'abc123'
            $updateUrl = 'https://edge.microsoft.com/blah'
            $installationMode = 'force_installed'
            $minimumVersionRequired = '1.0'
            Add-ADTEdgeExtension -ExtensionID $extensionId -UpdateUrl $updateUrl -InstallationMode $installationMode -MinimumVersionRequired $minimumVersionRequired

            $Extensions = Get-ItemPropertyValue -Path $RedirectedEdgeKey -Name 'ExtensionSettings' | ConvertFrom-Json
            $Extensions.$extensionId.update_url | Should -Be $updateUrl
            $Extensions.$extensionId.installation_mode | Should -Be $installationMode
            $Extensions.$extensionId.minimum_version_required | Should -Be $minimumVersionRequired
            ($Extensions.PSObject.Properties.Name | Measure-Object).Count | Should -Be 1
        }

        It 'Should update an existing extension registration, removing minimum version required' {

            New-Item -Path $RedirectedEdgeKey -Force | Out-Null
            New-ItemProperty -Path $RedirectedEdgeKey -Name 'ExtensionSettings' -Value '{"abc123":{"installation_mode":"blocked","update_url":"https://edge.microsoft.com/old","minimum_version_required":"1.0"}}' -Force | Out-Null

            $extensionId = 'abc123'
            $updateUrl = 'https://edge.microsoft.com/blah'
            $installationMode = 'force_installed'

            Add-ADTEdgeExtension -ExtensionID $extensionId -UpdateUrl $updateUrl -InstallationMode $installationMode

            $Extensions = Get-ItemPropertyValue -Path $RedirectedEdgeKey -Name 'ExtensionSettings' | ConvertFrom-Json
            $Extensions.$extensionId.update_url | Should -Be $updateUrl
            $Extensions.$extensionId.installation_mode | Should -Be $installationMode
            $Extensions.$extensionId | Select-Object -ExpandProperty minimum_version_required -ErrorAction Ignore | Should -BeNullOrEmpty
            ($Extensions.PSObject.Properties.Name | Measure-Object).Count | Should -Be 1
        }

        It 'Should preserve existing extensions' {

            New-Item -Path $RedirectedEdgeKey -Force | Out-Null
            New-ItemProperty -Path $RedirectedEdgeKey -Name 'ExtensionSettings' -Value '{"xyz789":{"installation_mode":"blocked","update_url":"https://edge.microsoft.com/old"}}' -Force | Out-Null

            $extensionId = 'abc123'
            $updateUrl = 'https://edge.microsoft.com/blah'
            $installationMode = 'force_installed'

            Add-ADTEdgeExtension -ExtensionID $extensionId -UpdateUrl $updateUrl -InstallationMode $installationMode

            $Extensions = Get-ItemPropertyValue -Path $RedirectedEdgeKey -Name 'ExtensionSettings' | ConvertFrom-Json
            $Extensions.$extensionId.update_url | Should -Be $updateUrl
            $Extensions.$extensionId.installation_mode | Should -Be $installationMode

            $Extensions.xyz789.update_url | Should -Be 'https://edge.microsoft.com/old'
            $Extensions.xyz789.installation_mode | Should -Be 'blocked'

            ($Extensions.PSObject.Properties.Name | Measure-Object).Count | Should -Be 2
        }
    }

    Context 'Input Validation' {
        It 'Should only accept InstallationMode as: blocked, allowed, removed, force_installed, normal_installed' {
            foreach ($mode in 'blocked', 'allowed', 'removed', 'force_installed', 'normal_installed')
            {
                { Add-ADTEdgeExtension -ExtensionID 'abc123' -UpdateUrl 'https://edge.microsoft.com/blah' -InstallationMode $mode } | Should -Not -Throw
            }

            { Add-ADTEdgeExtension -ExtensionID 'abc123' -UpdateUrl 'https://edge.microsoft.com/blah' -InstallationMode 'invalid' } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException]) -ErrorId 'ParameterArgumentValidationError,Add-ADTEdgeExtension'
        }

        It 'Should only accept valid URLs for UpdateUrl' {
            { Add-ADTEdgeExtension -ExtensionID 'abc123' -UpdateUrl 'https://edge.microsoft.com/blah' -InstallationMode 'force_installed' } | Should -Not -Throw
            { Add-ADTEdgeExtension -ExtensionID 'abc123' -UpdateUrl 'invalid' -InstallationMode 'force_installed' } | Should -Throw -ExceptionType ([System.ArgumentException]) -ErrorId 'InvalidUpdateUrlParameterValue,Add-ADTEdgeExtension'
        }
    }
}
