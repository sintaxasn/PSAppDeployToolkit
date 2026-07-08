BeforeDiscovery {
    # Removing a font unregisters it from the OS (system Fonts directory + HKLM), which requires
    # elevation and has no isolated fixture. Skip the whole suite when not elevated rather than
    # failing discovery with a #Requires statement.
    $script:IsElevated = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force

    # Mocked due to their expense when running via Pester.
    Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
    Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }

    $script:FontsDir = "$env:SystemRoot\Fonts"
    $script:FontRegKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    # Installs a real system .ttf under a unique name via Add-ADTFont and returns its file name,
    # registry name, and installed path so a test can then remove and verify it.
    function Install-TestFont
    {
        $source = Get-ChildItem "$script:FontsDir\*.ttf" | Select-Object -First 1 -ExpandProperty FullName
        if (-not $source)
        {
            throw 'No system .ttf font available to use as a test fixture.'
        }
        $fileName = "PesterRemove_$([System.Guid]::NewGuid().ToString('N').Substring(0, 8)).ttf"
        $testDrivePath = Join-Path $TestDrive $fileName
        Copy-Item -LiteralPath $source -Destination $testDrivePath -Force
        Add-ADTFont -Path $testDrivePath

        $regKey = Get-Item -LiteralPath $script:FontRegKey
        $registryName = $regKey.Property | Where-Object { $regKey.GetValue($_) -eq $fileName } | Select-Object -First 1
        return [pscustomobject]@{
            FileName     = $fileName
            RegistryName = $registryName
            FilePath     = Join-Path $script:FontsDir $fileName
        }
    }

    # Best-effort cleanup for a test font a failing test may have left installed.
    function Remove-TestFont
    {
        param([Parameter(Mandatory)][string]$FileName)
        Remove-ADTFont -Name $FileName -ErrorAction SilentlyContinue
    }
}

Describe 'Remove-ADTFont' -Skip:(-not $script:IsElevated) {
    Context 'Functionality' {
        BeforeEach {
            $script:TestFont = Install-TestFont
        }

        AfterEach {
            if ($script:TestFont)
            {
                Remove-TestFont -FileName $script:TestFont.FileName
                $script:TestFont = $null
            }
        }

        It 'Removes a font by file name, deleting both the file and its registry entry' {
            $script:TestFont.FilePath | Should -Exist

            Remove-ADTFont -Name $script:TestFont.FileName

            $script:TestFont.FilePath | Should -Not -Exist
            $regKey = Get-Item -LiteralPath $script:FontRegKey
            ($regKey.Property | Where-Object { $regKey.GetValue($_) -eq $script:TestFont.FileName }) | Should -BeNullOrEmpty
        }

        It 'Removes a font by its registry name' {
            if (-not $script:TestFont.RegistryName)
            {
                Set-ItResult -Skipped -Because 'the registry name could not be determined'
                return
            }

            Remove-ADTFont -Name $script:TestFont.RegistryName

            $script:TestFont.FilePath | Should -Not -Exist
        }
    }

    Context 'Error Handling' {
        It 'Does not throw when the font does not exist' {
            $nonExistent = "NonExistent_$([System.Guid]::NewGuid().ToString('N')).ttf"

            { Remove-ADTFont -Name $nonExistent } | Should -Not -Throw
        }
    }
}
