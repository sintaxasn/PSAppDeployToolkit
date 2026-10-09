BeforeAll {
    Import-Module "$PSScriptRoot\..\Support\PSAppDeployToolkit.TestHelpers.psm1"
    Import-ADTModuleUnderTest -Force

    Mock -ModuleName PSAppDeployToolkit Exit-ADTInvocation { }
    Initialize-ADTTestModule -Path $TestDrive
    Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }
}

AfterAll {
    Import-ADTModuleUnderTest -Force
}

Describe 'Fluent accent configuration forwarding' {
    BeforeEach {
        $script:Config = Get-ADTConfig
        $script:OriginalUI = @{
            DialogStyle = $script:Config.UI.DialogStyle
            FluentAccentColor = $script:Config.UI.FluentAccentColor
            FluentAccentColorDark = $script:Config.UI.FluentAccentColorDark
            FluentAccentColorExact = $script:Config.UI.FluentAccentColorExact
        }
        $script:Config.UI.DialogStyle = 'Fluent'
        $script:Config.UI.FluentAccentColor = 0xFF0078D7
        $script:Config.UI.FluentAccentColorDark = 0xFF60CDFF
        Mock -ModuleName PSAppDeployToolkit Get-ADTClientServerUser { [PSADT.AccountManagement.AccountUtilities]::CallerRunAsActiveUser }
        Mock -ModuleName PSAppDeployToolkit Invoke-ADTClientServerOperation { }
        Mock -ModuleName PSAppDeployToolkit Test-ADTClientServerActive { $false }
        Mock -ModuleName PSAppDeployToolkit Test-ADTInstallationProgressOpen { $false }
    }

    AfterEach {
        foreach ($key in $script:OriginalUI.Keys)
        {
            $script:Config.UI.$key = $script:OriginalUI.$key
        }
    }

    It 'Forwards exact mode <Exact> to a new progress dialog' -ForEach @(
        @{ Exact = $false }
        @{ Exact = $true }
    ) {
        $script:Config.UI.FluentAccentColorExact = $Exact
        Show-ADTInstallationProgress -Title 'Accent forwarding' -Subtitle 'Progress' -StatusMessage 'Installing'

        Should -Invoke -ModuleName PSAppDeployToolkit Invoke-ADTClientServerOperation -Times 1 -Exactly -ParameterFilter {
            $ShowProgressDialog -and ($DialogStyle -eq 'Fluent') -and ($Options.FluentAccentColorExact -eq $Exact)
        }
    }

    It 'Forwards exact mode <Exact> to an installation prompt' -ForEach @(
        @{ Exact = $false }
        @{ Exact = $true }
    ) {
        $script:Config.UI.FluentAccentColorExact = $Exact
        Show-ADTInstallationPrompt -Title 'Accent forwarding' -Subtitle 'Prompt' -Message 'Install this application?' -ButtonRightText 'OK' -NoWait

        Should -Invoke -ModuleName PSAppDeployToolkit Invoke-ADTClientServerOperation -Times 1 -Exactly -ParameterFilter {
            $ShowModalDialog -and ($DialogType -eq 'CustomDialog') -and ($DialogStyle -eq 'Fluent') -and ($Options.FluentAccentColorExact -eq $Exact)
        }
    }

    It 'Forwards exact mode <Exact> to the welcome dialog' -ForEach @(
        @{ Exact = $false }
        @{ Exact = $true }
    ) {
        $script:Config.UI.FluentAccentColorExact = $Exact
        Mock -ModuleName PSAppDeployToolkit Get-ADTDeferHistory { }
        Mock -ModuleName PSAppDeployToolkit Invoke-ADTClientServerOperation { [PSADT.UserInterface.DialogResults.CloseAppsDialogResult]::Continue } -ParameterFilter { $ShowModalDialog }

        # A forced continue countdown shows the welcome dialog without having to find or close any
        # real processes. The mocked response lets it finish without waiting on the countdown.
        Show-ADTInstallationWelcome -Title 'Accent forwarding' -Subtitle 'Welcome' -AllowDefer -ForceCountdown ([System.TimeSpan]::FromSeconds(1)) -MinimizeWindows:$false

        Should -Invoke -ModuleName PSAppDeployToolkit Invoke-ADTClientServerOperation -Times 1 -Exactly -ParameterFilter {
            $ShowModalDialog -and ($DialogType -eq 'CloseAppsDialog') -and ($DialogStyle -eq 'Fluent') -and ($Options.FluentAccentColorExact -eq $Exact)
        }
    }

    It 'Forwards exact mode <Exact> to the restart dialog' -ForEach @(
        @{ Exact = $false }
        @{ Exact = $true }
    ) {
        $script:Config.UI.FluentAccentColorExact = $Exact
        Show-ADTInstallationRestartPrompt -Title 'Accent forwarding' -Subtitle 'Restart' -NoInteractiveCountdown

        Should -Invoke -ModuleName PSAppDeployToolkit Invoke-ADTClientServerOperation -Times 1 -Exactly -ParameterFilter {
            $ShowModalDialog -and ($DialogType -eq 'RestartDialog') -and ($DialogStyle -eq 'Fluent') -and ($Options.FluentAccentColorExact -eq $Exact)
        }
    }

    Context 'Blocked-application dialog' {
        BeforeEach {
            $null = Open-ADTSession -SessionState $ExecutionContext.SessionState -AppName 'AccentBlockForwarding' -DeployMode Silent -PassThru -InformationAction SilentlyContinue
            $script:BlockEnvironment = @{}
            foreach ($property in (Get-ADTEnvironmentTable).PSObject.Properties)
            {
                $script:BlockEnvironment[$property.Name] = $property.Value
            }
            $script:BlockEnvironment.IsAdmin = $true
            Mock -ModuleName PSAppDeployToolkit Get-ADTEnvironmentTable { $script:BlockEnvironment }
            Mock -ModuleName PSAppDeployToolkit Test-ADTClientServerActive { $true }
            Mock -ModuleName PSAppDeployToolkit Get-ScheduledTask { }
            Mock -ModuleName PSAppDeployToolkit Set-ADTRegistryKey { }
            Mock -ModuleName PSAppDeployToolkit New-ADTDialogOptionsObject { $Type::new($Data) }
        }

        AfterEach {
            Close-ADTSession -ExitCode 0 -NoShellExit -InformationAction SilentlyContinue
        }

        It 'Forwards exact mode <Exact> into the serialized blocked-application options' -ForEach @(
            @{ Exact = $false }
            @{ Exact = $true }
        ) {
            $script:Config.UI.FluentAccentColorExact = $Exact

            # Registry storage is mocked, and WhatIf stops at scheduled-task creation before any IFEO
            # writes. The options constructor remains real so the serialized type is also exercised.
            Block-ADTAppExecution -Processes @{ Name = 'adtexactaccenttest' } -WhatIf

            Should -Invoke -ModuleName PSAppDeployToolkit New-ADTDialogOptionsObject -Times 1 -Exactly -ParameterFilter {
                ($Type -eq [PSADT.UserInterface.DialogOptions.CustomDialogOptions]) -and $Data.ContainsKey('FluentAccentColorExact') -and ($Data.FluentAccentColorExact -eq $Exact)
            }
            Should -Invoke -ModuleName PSAppDeployToolkit Set-ADTRegistryKey -Times 1 -Exactly
        }
    }
}
