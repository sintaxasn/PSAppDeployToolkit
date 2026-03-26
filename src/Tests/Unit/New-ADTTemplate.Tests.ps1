BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force
}

Describe 'New-ADTTemplate' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }

        # Create one shared v4 template used by most tests. Done once to keep the suite fast.
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'V4Name', Justification = 'Used in It blocks.')]
        $V4Name = "ADTTemplate_v4_$([System.Guid]::NewGuid().ToString('N'))"

        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'V4Result', Justification = 'Used in It blocks.')]
        $V4Result = New-ADTTemplate -Destination $TestDrive -Name $V4Name -PassThru
    }

    AfterAll {
        # Clear read-only attributes on all created files so Pester's TestDrive cleanup succeeds.
        Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File -ErrorAction SilentlyContinue |
            ForEach-Object { try { $_.Attributes = [System.IO.FileAttributes]::Normal } catch { $null = $_ } }
    }

    Context '-PassThru and directory structure (v4)' {
        It 'Returns a DirectoryInfo when -PassThru is specified' {
            $V4Result | Should -BeOfType [System.IO.DirectoryInfo]
        }

        It 'Returned DirectoryInfo Name matches the supplied -Name' {
            $V4Result.Name | Should -Be $V4Name
        }

        It 'Creates a Files subdirectory' {
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V4Name\Files") -PathType Container | Should -BeTrue
        }

        It 'Creates a SupportFiles subdirectory' {
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V4Name\SupportFiles") -PathType Container | Should -BeTrue
        }

        It 'Copies the Config directory' {
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V4Name\Config") -PathType Container | Should -BeTrue
        }

        It 'Copies the Assets directory' {
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V4Name\Assets") -PathType Container | Should -BeTrue
        }

        It 'Copies the Strings directory' {
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V4Name\Strings") -PathType Container | Should -BeTrue
        }

        It 'Returns nothing when -PassThru is not specified' {
            $noPassThru = New-ADTTemplate -Destination $TestDrive -Name "ADTTemplate_nopt_$([System.Guid]::NewGuid().ToString('N'))"
            $noPassThru | Should -BeNull
        }
    }

    Context 'Version 4 module placement' {
        It 'Places the module directly under the template root' {
            # v4: $templateModulePath = <template>\PSAppDeployToolkit
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V4Name\PSAppDeployToolkit") -PathType Container | Should -BeTrue
        }
    }

    Context 'Version 3 module placement' {
        BeforeAll {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'V3Name', Justification = 'Used in It blocks.')]
            $V3Name = "ADTTemplate_v3_$([System.Guid]::NewGuid().ToString('N'))"
            New-ADTTemplate -Destination $TestDrive -Name $V3Name -Version 3
        }

        AfterAll {
            # Clear read-only attributes on the v3 template tree.
            $v3Root = Join-Path -Path $TestDrive -ChildPath $V3Name
            if (Test-Path -LiteralPath $v3Root)
            {
                Get-ChildItem -LiteralPath $v3Root -Recurse -Force -File -ErrorAction SilentlyContinue |
                    ForEach-Object { try { $_.Attributes = [System.IO.FileAttributes]::Normal } catch { $null = $_ } }
            }
        }

        It 'Places the module under an AppDeployToolkit subdirectory' {
            # v3: $templateModulePath = <template>\AppDeployToolkit\PSAppDeployToolkit
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath "$V3Name\AppDeployToolkit\PSAppDeployToolkit") -PathType Container | Should -BeTrue
        }
    }

    Context 'Existing non-empty folder handling' {
        BeforeAll {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ExistingName', Justification = 'Used in It blocks.')]
            $ExistingName = "ADTTemplate_existing_$([System.Guid]::NewGuid().ToString('N'))"
            # Pre-create a non-empty folder at the destination.
            $null = New-Item -Path (Join-Path -Path $TestDrive -ChildPath "$ExistingName\SomeFile.txt") -ItemType File -Force
        }

        AfterAll {
            $existingRoot = Join-Path -Path $TestDrive -ChildPath $ExistingName
            if (Test-Path -LiteralPath $existingRoot)
            {
                Get-ChildItem -LiteralPath $existingRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
                    ForEach-Object { try { $_.Attributes = [System.IO.FileAttributes]::Normal } catch { $null = $_ } }
            }
        }

        It 'Throws when the destination exists and is non-empty without -Force' {
            { New-ADTTemplate -Destination $TestDrive -Name $ExistingName } | Should -Throw
        }

        It 'Does not throw when the destination is non-empty and -Force is specified' {
            { New-ADTTemplate -Destination $TestDrive -Name $ExistingName -Force } | Should -Not -Throw
        }
    }

    Context 'Input validation' {
        It 'Throws when -Version is below the minimum (< 3)' {
            { New-ADTTemplate -Destination $TestDrive -Name "BadVer_$([System.Guid]::NewGuid().ToString('N'))" -Version 2 } | Should -Throw
        }

        It 'Throws when -Version is above the maximum (> 4)' {
            { New-ADTTemplate -Destination $TestDrive -Name "BadVer_$([System.Guid]::NewGuid().ToString('N'))" -Version 5 } | Should -Throw
        }

        It 'Throws when -Name is an empty string' {
            { New-ADTTemplate -Destination $TestDrive -Name '' } | Should -Throw
        }
    }
}
