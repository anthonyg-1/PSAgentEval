#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester BeforeAll/BeforeEach variables are accessible in It/AfterEach blocks')]
param()

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'PSAgentEval.psd1'
    $modulePath = (Resolve-Path $modulePath).Path
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module PSAgentEval -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-AgentRedTeam' {

    Context 'API key resolution' {
        BeforeEach {
            $savedKey = $env:ANTHROPIC_API_KEY
            Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
        }

        AfterEach {
            if ($null -ne $savedKey) {
                $env:ANTHROPIC_API_KEY = $savedKey
            } else {
                Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
            }
        }

        It 'Throws MissingApiKey when neither -ApiKey nor env var is set' {
            { Invoke-AgentRedTeam } |
                Should -Throw -ErrorId 'MissingApiKey,Invoke-AgentRedTeam'
        }

        It 'Throws MissingApiKey when -ApiKey is an empty string and env var is absent' {
            { Invoke-AgentRedTeam -ApiKey '' } |
                Should -Throw -ErrorId 'MissingApiKey,Invoke-AgentRedTeam'
        }

        It 'Does not throw MissingApiKey when a non-empty -ApiKey is provided' {
            $err = $null
            try { Invoke-AgentRedTeam -ApiKey 'sk-test' } catch { $err = $_ }
            $err.FullyQualifiedErrorId | Should -Not -Be 'MissingApiKey,Invoke-AgentRedTeam' `
                -Because 'any subsequent error is a key-validation or scan error, not the empty-key guard'
        }

        It 'Does not throw MissingApiKey when the env var is set' {
            $env:ANTHROPIC_API_KEY = 'sk-env-test'
            $err = $null
            try { Invoke-AgentRedTeam } catch { $err = $_ }
            $err.FullyQualifiedErrorId | Should -Not -Be 'MissingApiKey,Invoke-AgentRedTeam' `
                -Because 'any subsequent error is a key-validation or scan error, not the empty-key guard'
        }

        It 'Throws InvalidApiKey when a bogus key is supplied' {
            { Invoke-AgentRedTeam -ApiKey 'sk-ant-bogus' } |
                Should -Throw -ErrorId 'InvalidApiKey,Invoke-AgentRedTeam'
        }
    }

    Context 'Parameter validation' {
        It 'Throws on an unrecognised Intensity value' {
            { Invoke-AgentRedTeam -ApiKey 'sk-test' -Intensity 'Turbo' } | Should -Throw
        }

        It 'Throws on a negative RateLimitMs value' {
            { Invoke-AgentRedTeam -ApiKey 'sk-test' -RateLimitMs -1 } | Should -Throw
        }
    }

    Context 'Parameter metadata' {
        BeforeAll {
            $cmd = Get-Command Invoke-AgentRedTeam
            $vs  = $cmd.Parameters['Intensity'].Attributes |
                       Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        }

        It 'Exposes a -<Name> parameter' -ForEach @(
            @{ Name = 'Model' }
            @{ Name = 'SystemPrompt' }
            @{ Name = 'Intensity' }
            @{ Name = 'RateLimitMs' }
            @{ Name = 'FailFast' }
        ) {
            $cmd.Parameters.ContainsKey($Name) | Should -BeTrue
        }

        It '-Intensity has a ValidateSet attribute' {
            $vs | Should -Not -BeNullOrEmpty
        }

        It '-Intensity ValidateSet includes <_>' -ForEach @('Quick', 'Moderate', 'Comprehensive') {
            $vs.ValidValues | Should -Contain $_
        }

        It '-RateLimitMs has a ValidateRange attribute' {
            $cmd.Parameters['RateLimitMs'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] } |
                Should -Not -BeNullOrEmpty
        }

        It '-FailFast is a SwitchParameter' {
            $cmd.Parameters['FailFast'].ParameterType |
                Should -Be ([System.Management.Automation.SwitchParameter])
        }

        It 'Declares an [OutputType] of PSObject' {
            $cmd.OutputType | Where-Object { $_.Type -eq [PSObject] } |
                Should -Not -BeNullOrEmpty
        }
    }
}
