BeforeAll {
    Remove-Module PSAppDeployToolkit -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\..\..\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -Force
}

Describe 'Test-ADTMutexAvailability' {
    BeforeAll {
        # Mock Set-ADTPreferenceVariables to avoid changing preference state during tests.
        Mock -ModuleName PSAppDeployToolkit Set-ADTPreferenceVariables { }
        # Mock Write-ADTLogEntry due to its expense when running via Pester.
        Mock -ModuleName PSAppDeployToolkit Write-ADTLogEntry { }
    }

    Context 'Return type' {
        It 'Returns a System.Boolean' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            Test-ADTMutexAvailability -MutexName $name | Should -BeOfType [System.Boolean]
        }
    }

    Context 'Nonexistent mutex (free)' {
        It 'Returns $true for a mutex name that does not exist' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            Test-ADTMutexAvailability -MutexName $name | Should -Be $true
        }

        It 'Does not throw for a nonexistent mutex' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            { Test-ADTMutexAvailability -MutexName $name } | Should -Not -Throw
        }

        It 'Can be called multiple times consecutively without error' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            { Test-ADTMutexAvailability -MutexName $name; Test-ADTMutexAvailability -MutexName $name } | Should -Not -Throw
        }
    }

    Context 'Held mutex (not free)' {
        It 'Returns $false when another thread holds the mutex' {
            if (-not (Get-Command Start-ThreadJob -ErrorAction Ignore))
            {
                Set-ItResult -Skipped -Because 'Start-ThreadJob is not available (requires ThreadJob module or PowerShell 6.3+)'
                return
            }
            $name = "ADTTest_Held_$([System.Guid]::NewGuid().ToString('N'))"

            # Use a .NET Semaphore to signal when the background thread is ready.
            $readySignal = [System.Threading.SemaphoreSlim]::new(0, 1)

            # Acquire the mutex in a background thread job; Mutex is thread-affine so the
            # main thread cannot acquire what another thread owns — WaitOne will return $false.
            $job = Start-ThreadJob -ScriptBlock {
                $bgMutex = [System.Threading.Mutex]::new($true, $using:name)
                [void]($using:readySignal).Release()    # Signal: mutex is now held
                [System.Threading.Thread]::Sleep(10000)
                $bgMutex.ReleaseMutex()
                $bgMutex.Dispose()
            }

            # Wait for the background thread to actually acquire the mutex (max 5s).
            $null = $readySignal.Wait([System.TimeSpan]::FromSeconds(5))

            try
            {
                $result = Test-ADTMutexAvailability -MutexName $name -MutexWaitTime ([System.TimeSpan]::Zero)
                $result | Should -Be $false
            }
            finally
            {
                Stop-Job $job
                Remove-Job $job
                $readySignal.Dispose()
            }
        }
    }

    Context 'Logging' {
        It 'Calls Write-ADTLogEntry at least once per invocation' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            Test-ADTMutexAvailability -MutexName $name
            Should -Invoke Write-ADTLogEntry -ModuleName PSAppDeployToolkit -Scope It
        }
    }

    Context 'MutexWaitTime parameter' {
        It 'Accepts a zero TimeSpan without throwing' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            { Test-ADTMutexAvailability -MutexName $name -MutexWaitTime ([System.TimeSpan]::Zero) } | Should -Not -Throw
        }

        It 'Accepts a positive TimeSpan without throwing' {
            $name = "ADTTest_$([System.Guid]::NewGuid().ToString('N'))"
            { Test-ADTMutexAvailability -MutexName $name -MutexWaitTime ([System.TimeSpan]::FromMilliseconds(10)) } | Should -Not -Throw
        }
    }

    Context 'Input validation' {
        It 'Throws when -MutexName is an empty string (ValidateLength min = 1)' {
            { Test-ADTMutexAvailability -MutexName '' } | Should -Throw
        }

        It 'Throws when -MutexName exceeds 260 characters (ValidateLength max = 260)' {
            { Test-ADTMutexAvailability -MutexName ('A' * 261) } | Should -Throw
        }

        It 'Accepts a name of exactly 260 characters without throwing' {
            { Test-ADTMutexAvailability -MutexName ('A' * 260) } | Should -Not -Throw
        }
    }
}
