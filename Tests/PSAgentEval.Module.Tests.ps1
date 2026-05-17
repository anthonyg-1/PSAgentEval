#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'PSAgentEval.psd1'
    if (-not (Test-Path $modulePath)) {
        throw "Module manifest not found at: $modulePath"
    }
    $modulePath = (Resolve-Path $modulePath).Path
    Import-Module $modulePath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module PSAgentEval -Force -ErrorAction SilentlyContinue
}

Describe 'PSAgentEval Module' {

    Context 'Manifest' {
        It 'Has a valid manifest' {
            { Test-ModuleManifest -Path $modulePath -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Reports version 0.1.4' {
            (Test-ModuleManifest -Path $modulePath).Version | Should -Be '0.1.4'
        }

        It 'Requires PowerShell 7.5.0 or higher' {
            (Test-ModuleManifest -Path $modulePath).PowerShellVersion | Should -Be '7.5.0'
        }
    }

    Context 'Exports' {
        It 'Exports Invoke-AgentRedTeam' {
            (Get-Module PSAgentEval).ExportedFunctions.Keys | Should -Contain 'Invoke-AgentRedTeam'
        }

        It 'Exports exactly one function' {
            (Get-Module PSAgentEval).ExportedFunctions.Count | Should -Be 1
        }

        It 'Does not export private function <_>' -ForEach @(
            'ConvertTo-PSRedTeamResult',
            'ConvertTo-PSAttackResult',
            'ConvertTo-PSProbeResult'
        ) {
            (Get-Module PSAgentEval).ExportedFunctions.Keys | Should -Not -Contain $_
        }
    }
}
