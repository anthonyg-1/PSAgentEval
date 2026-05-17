#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester BeforeAll variables are accessible in It blocks')]
param()

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'PSAgentEval.psd1'
    $modulePath = (Resolve-Path $modulePath).Path
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module PSAgentEval -Force -ErrorAction SilentlyContinue
}

Describe 'Test-ApiKey' {

    Context 'Bogus key' {
        BeforeAll {
            # One network call shared across all assertions in this context.
            # A bogus key yields a fast 401 (or connection error), both caught as InvalidApiKey.
            $script:capturedErr = InModuleScope PSAgentEval {
                $e = $null
                try { Test-ApiKey -ApiKey 'sk-ant-bogus' } catch { $e = $_ }
                $e
            }
        }

        It 'Throws (non-null error record)' {
            $script:capturedErr | Should -Not -BeNullOrEmpty
        }

        It 'Reports ErrorId as InvalidApiKey' {
            $script:capturedErr.FullyQualifiedErrorId | Should -BeLike 'InvalidApiKey*'
        }

        It 'Reports AuthenticationError category' {
            $script:capturedErr.CategoryInfo.Category | Should -Be ([System.Management.Automation.ErrorCategory]::AuthenticationError)
        }

        It 'Wraps an UnauthorizedAccessException' {
            $script:capturedErr.Exception | Should -BeOfType [System.UnauthorizedAccessException]
        }

        It 'Exception message contains the upstream cause' {
            $script:capturedErr.Exception.Message | Should -BeLike 'API key validation failed:*'
        }
    }

    Context 'Parameter contract' {
        It 'Accepts -ApiKey as a mandatory string' {
            $cmd = InModuleScope PSAgentEval { Get-Command Test-ApiKey }
            $cmd.Parameters.ContainsKey('ApiKey') | Should -BeTrue
        }

        It '-ApiKey is mandatory' {
            $cmd  = InModuleScope PSAgentEval { Get-Command Test-ApiKey }
            $attr = $cmd.Parameters['ApiKey'].Attributes |
                        Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }
    }
}
