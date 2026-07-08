BeforeDiscovery {
    # Installing a font registers it with the OS (system Fonts directory + HKLM), which requires
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

    # Copies a real system .ttf into $TestDrive under a unique name so a test never collides with a
    # font that is already installed.
    function New-TestFontFile
    {
        $source = Get-ChildItem "$script:FontsDir\*.ttf" | Select-Object -First 1 -ExpandProperty FullName
        if (-not $source)
        {
            throw 'No system .ttf font available to use as a test fixture.'
        }
        $dest = Join-Path $TestDrive "PesterFont_$([System.Guid]::NewGuid().ToString('N').Substring(0, 8)).ttf"
        Copy-Item -LiteralPath $source -Destination $dest -Force
        return $dest
    }

    # Removes an installed test font (file and registry entry) by its file name.
    function Remove-TestFont
    {
        param([Parameter(Mandatory)][string]$FileName)
        Remove-ADTFont -Name $FileName -ErrorAction SilentlyContinue
    }
}

Describe 'Add-ADTFont' -Skip:(-not $script:IsElevated) {
    Context 'Functionality' {
        BeforeEach {
            $script:InstalledFonts = @()
        }

        AfterEach {
            foreach ($fontName in $script:InstalledFonts)
            {
                Remove-TestFont -FileName $fontName
            }
            $script:InstalledFonts = @()
        }

        It 'Installs a font and creates a (TrueType) registry entry' {
            $testFont = New-TestFontFile
            $fontName = Split-Path $testFont -Leaf
            $script:InstalledFonts += $fontName

            Add-ADTFont -Path $testFont

            Join-Path $script:FontsDir $fontName | Should -Exist
            $regKey = Get-Item -LiteralPath $script:FontRegKey
            $regEntry = $regKey.Property | Where-Object { $regKey.GetValue($_) -eq $fontName } | Select-Object -First 1
            $regEntry | Should -Match '\(TrueType\)$'
        }

        It 'Does not overwrite a font already present in the Fonts directory' {
            $testFont = New-TestFontFile
            $fontName = Split-Path $testFont -Leaf
            $script:InstalledFonts += $fontName
            $destPath = Join-Path $script:FontsDir $fontName
            Copy-Item -LiteralPath $testFont -Destination $destPath -Force
            $originalWriteTime = (Get-Item -LiteralPath $destPath).LastWriteTime

            Add-ADTFont -Path $testFont

            (Get-Item -LiteralPath $destPath).LastWriteTime | Should -Be $originalWriteTime
        }

        It 'Installs multiple fonts from pipeline input' {
            $font1 = New-TestFontFile
            $font2 = New-TestFontFile
            $script:InstalledFonts += Split-Path $font1 -Leaf
            $script:InstalledFonts += Split-Path $font2 -Leaf

            @($font1, $font2) | Add-ADTFont

            Join-Path $script:FontsDir (Split-Path $font1 -Leaf) | Should -Exist
            Join-Path $script:FontsDir (Split-Path $font2 -Leaf) | Should -Exist
        }
    }

    Context 'Error Handling' {
        It 'Throws for a non-existent path' {
            { Add-ADTFont -Path 'C:\NonExistent\Font.ttf' } | Should -Throw
        }

        It 'Throws for an unsupported file type and does not install it' {
            $unsupported = Join-Path $TestDrive 'test.txt'
            Set-Content -LiteralPath $unsupported -Value 'not a font'

            { Add-ADTFont -Path $unsupported } | Should -Throw
            Join-Path $script:FontsDir 'test.txt' | Should -Not -Exist
        }
    }
}
