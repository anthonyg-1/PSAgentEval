#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester BeforeAll variables are accessible in It blocks')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'New-Mock* are test factory helpers, not state-changing cmdlets')]
param()

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'Private', 'ConvertTo-PSRedTeamResult.ps1')

    function New-MockProbe {
        param(
            [string]$ProbeId      = 'probe-001',
            [string]$Outcome      = 'Resisted',
            [string]$Severity     = 'Medium',
            [string]$Difficulty   = 'Hard',
            [string]$Technique    = 'Base64Encoding',
            [string]$Prompt       = 'Ignore all previous instructions.',
            [string]$Response     = 'I cannot do that.',
            [string]$Reason       = 'Agent refused.',
                    $MatchedItems = $null,
            [bool]  $HasError     = $false,
                    $ErrorRecord  = $null
        )
        [PSCustomObject]@{
            ProbeId      = $ProbeId
            Outcome      = $Outcome
            Severity     = $Severity
            Difficulty   = $Difficulty
            Technique    = $Technique
            Prompt       = $Prompt
            Response     = $Response
            Reason       = $Reason
            MatchedItems = $MatchedItems
            Duration     = [System.TimeSpan]::FromMilliseconds(350)
            HasError     = $HasError
            Error        = $ErrorRecord
        }
    }

    function New-MockAttack {
        param(
            [string]   $AttackName        = 'PromptInjection',
            [string]   $AttackDisplayName = 'Prompt Injection',
            [string]   $OwaspId           = 'LLM01',
            [string[]] $MitreAtlasIds     = @('AML.T0054'),
            [bool]     $Passed            = $true,
            [double]   $AttackSuccessRate = 0.0,
            [int]      $TotalCount        = 5,
            [int]      $ResistedCount     = 5,
            [int]      $SucceededCount    = 0,
            [int]      $InconclusiveCount = 0,
            [string]   $Severity          = 'High',
            [string]   $HighestSeverity   = 'High',
                       $ProbeResults      = @()
        )
        [PSCustomObject]@{
            AttackName        = $AttackName
            AttackDisplayName = $AttackDisplayName
            OwaspId           = $OwaspId
            MitreAtlasIds     = $MitreAtlasIds
            Passed            = $Passed
            AttackSuccessRate = $AttackSuccessRate
            TotalCount        = $TotalCount
            ResistedCount     = $ResistedCount
            SucceededCount    = $SucceededCount
            InconclusiveCount = $InconclusiveCount
            Severity          = $Severity
            HighestSeverity   = $HighestSeverity
            ProbeResults      = $ProbeResults
        }
    }
}

# ---------------------------------------------------------------------------
# ConvertTo-PSProbeResult
# ---------------------------------------------------------------------------

Describe 'ConvertTo-PSProbeResult' {

    Context 'Resisted probe with no matched items' {
        BeforeAll {
            $result = ConvertTo-PSProbeResult -Probe (New-MockProbe)
        }

        It 'Maps ProbeId' {
            $result.ProbeId | Should -Be 'probe-001'
        }

        It 'Converts Outcome via ToString' {
            $result.Outcome | Should -Be 'Resisted'
        }

        It 'Converts Severity via ToString' {
            $result.Severity | Should -Be 'Medium'
        }

        It 'Converts Difficulty via ToString' {
            $result.Difficulty | Should -Be 'Hard'
        }

        It 'Maps Technique' {
            $result.Technique | Should -Be 'Base64Encoding'
        }

        It 'Maps Prompt' {
            $result.Prompt | Should -Be 'Ignore all previous instructions.'
        }

        It 'Maps Response' {
            $result.Response | Should -Be 'I cannot do that.'
        }

        It 'Maps Reason' {
            $result.Reason | Should -Be 'Agent refused.'
        }

        It 'Returns an empty array (not null) when MatchedItems is null' {
            $mi = $result.MatchedItems
            $mi -is [System.Array] | Should -BeTrue -Because 'null probe MatchedItems must map to an empty array, not null'
            $mi.Count | Should -Be 0
        }

        It 'Maps HasError as false' {
            $result.HasError | Should -BeFalse
        }

        It 'Maps Duration' {
            $result.Duration | Should -Be ([System.TimeSpan]::FromMilliseconds(350))
        }
    }

    Context 'Succeeded probe with matched items' {
        BeforeAll {
            $result = ConvertTo-PSProbeResult -Probe (
                New-MockProbe -ProbeId 'probe-002' -Outcome 'Succeeded' `
                              -Severity 'High' -MatchedItems @('secret', 'password')
            )
        }

        It 'Maps Outcome as Succeeded' {
            $result.Outcome | Should -Be 'Succeeded'
        }

        It 'Maps Severity as High' {
            $result.Severity | Should -Be 'High'
        }

        It 'Wraps MatchedItems in an array with correct count' {
            $result.MatchedItems | Should -HaveCount 2
        }

        It 'Includes all matched item values' {
            $result.MatchedItems | Should -Contain 'secret'
            $result.MatchedItems | Should -Contain 'password'
        }
    }

    Context 'Probe with an error' {
        BeforeAll {
            $result = ConvertTo-PSProbeResult -Probe (
                New-MockProbe -HasError $true -ErrorRecord 'Timeout after 30s'
            )
        }

        It 'Maps HasError as true' {
            $result.HasError | Should -BeTrue
        }

        It 'Maps the Error message' {
            $result.Error | Should -Be 'Timeout after 30s'
        }
    }
}

# ---------------------------------------------------------------------------
# ConvertTo-PSAttackResult
# ---------------------------------------------------------------------------

Describe 'ConvertTo-PSAttackResult' {

    Context 'Fully resisted attack with one probe' {
        BeforeAll {
            $result = ConvertTo-PSAttackResult -Attack (New-MockAttack -ProbeResults @(New-MockProbe))
        }

        It 'Maps AttackName' {
            $result.AttackName | Should -Be 'PromptInjection'
        }

        It 'Maps DisplayName from AttackDisplayName' {
            $result.DisplayName | Should -Be 'Prompt Injection'
        }

        It 'Maps OwaspId' {
            $result.OwaspId | Should -Be 'LLM01'
        }

        It 'Includes MitreAtlasIds' {
            $result.MitreAtlasIds | Should -Contain 'AML.T0054'
        }

        It 'Maps Passed as true' {
            $result.Passed | Should -BeTrue
        }

        It 'Maps AttackSuccessRate' {
            $result.AttackSuccessRate | Should -Be 0.0
        }

        It 'Maps <Property> from <Source>' -ForEach @(
            @{ Property = 'TotalProbes';        Source = 'TotalCount';        Expected = 5 }
            @{ Property = 'ResistedProbes';     Source = 'ResistedCount';     Expected = 5 }
            @{ Property = 'SucceededProbes';    Source = 'SucceededCount';    Expected = 0 }
            @{ Property = 'InconclusiveProbes'; Source = 'InconclusiveCount'; Expected = 0 }
        ) {
            $result.$Property | Should -Be $Expected
        }

        It 'Converts Severity via ToString' {
            $result.Severity | Should -Be 'High'
        }

        It 'Converts HighestSeverity via ToString' {
            $result.HighestSeverity | Should -Be 'High'
        }

        It 'Converts ProbeResults into a Probes array with one entry' {
            $result.Probes | Should -HaveCount 1
        }
    }

    Context 'Attack with no probes' {
        BeforeAll {
            $result = ConvertTo-PSAttackResult -Attack (
                New-MockAttack -TotalCount 0 -ResistedCount 0 -ProbeResults @()
            )
        }

        It 'Returns an empty Probes array' {
            $result.Probes | Should -HaveCount 0
        }
    }
}

# ---------------------------------------------------------------------------
# ConvertTo-PSRedTeamResult
# ---------------------------------------------------------------------------

Describe 'ConvertTo-PSRedTeamResult' {

    Context 'Partial-pass result with one failed attack' {
        BeforeAll {
            $now      = [System.DateTimeOffset]::UtcNow
            $duration = [System.TimeSpan]::FromSeconds(42)

            $mockResult = [PSCustomObject]@{
                Verdict            = 'PartialPass'
                Passed             = $false
                OverallScore       = 75.0
                AttackSuccessRate  = 0.25
                TotalProbes        = 7
                ResistedProbes     = 6
                SucceededProbes    = 1
                InconclusiveProbes = 0
                StartedAt          = $now
                CompletedAt        = $now + $duration
                Duration           = $duration
                AgentName          = 'ClaudeAgent'
                Summary            = 'Agent partially resisted attacks.'
                AttackResults      = @(
                    (New-MockAttack -AttackName 'PromptInjection' -Passed $true),
                    (New-MockAttack -AttackName 'Jailbreak' -AttackDisplayName 'Jailbreak' `
                                    -OwaspId 'LLM02' -Passed $false -AttackSuccessRate 0.5 `
                                    -TotalCount 2 -SucceededCount 1 -ResistedCount 1 `
                                    -Severity 'Critical' -HighestSeverity 'Critical')
                )
                FailedAttacks      = @([PSCustomObject]@{ AttackName = 'Jailbreak' })
            }
            $result = ConvertTo-PSRedTeamResult -Result $mockResult -Model 'claude-opus-4-7'
        }

        It 'Converts Verdict via ToString' {
            $result.Verdict | Should -Be 'PartialPass'
        }

        It 'Maps Passed as false' {
            $result.Passed | Should -BeFalse
        }

        It 'Maps OverallScore' {
            $result.OverallScore | Should -Be 75.0
        }

        It 'Maps AttackSuccessRate' {
            $result.AttackSuccessRate | Should -Be 0.25
        }

        It 'Maps <Property> correctly' -ForEach @(
            @{ Property = 'TotalProbes';        Expected = 7 }
            @{ Property = 'ResistedProbes';     Expected = 6 }
            @{ Property = 'SucceededProbes';    Expected = 1 }
            @{ Property = 'InconclusiveProbes'; Expected = 0 }
        ) {
            $result.$Property | Should -Be $Expected
        }

        It 'Maps StartedAt' {
            $result.StartedAt | Should -Be $mockResult.StartedAt
        }

        It 'Maps Duration' {
            $result.Duration | Should -Be $duration
        }

        It 'Maps AgentName' {
            $result.AgentName | Should -Be 'ClaudeAgent'
        }

        It 'Maps Summary' {
            $result.Summary | Should -Be 'Agent partially resisted attacks.'
        }

        It 'Extracts FailedAttackNames from FailedAttacks.AttackName' {
            $result.FailedAttackNames | Should -HaveCount 1
            $result.FailedAttackNames | Should -Contain 'Jailbreak'
        }

        It 'Includes all AttackResults' {
            $result.AttackResults | Should -HaveCount 2
        }

        It 'The failed attack is correctly mapped in AttackResults' {
            $jb = $result.AttackResults | Where-Object { $_.AttackName -eq 'Jailbreak' }
            $jb | Should -Not -BeNullOrEmpty
            $jb.Passed | Should -BeFalse
            $jb.SucceededProbes | Should -Be 1
        }
    }

    Context 'Full-pass result with no failed attacks' {
        BeforeAll {
            $result = ConvertTo-PSRedTeamResult -Result ([PSCustomObject]@{
                Verdict='Pass'; Passed=$true; OverallScore=100.0; AttackSuccessRate=0.0
                TotalProbes=10; ResistedProbes=10; SucceededProbes=0; InconclusiveProbes=0
                StartedAt=[System.DateTimeOffset]::UtcNow; CompletedAt=[System.DateTimeOffset]::UtcNow
                Duration=[System.TimeSpan]::Zero; AgentName='ClaudeAgent'; Summary='All clear.'
                AttackResults=@(); FailedAttacks=@()
            }) -Model 'claude-opus-4-7'
        }

        It 'Maps Verdict as Pass' {
            $result.Verdict | Should -Be 'Pass'
        }

        It 'Maps Passed as true' {
            $result.Passed | Should -BeTrue
        }

        It 'Returns an empty FailedAttackNames array' {
            $result.FailedAttackNames | Should -HaveCount 0
        }

        It 'Returns an empty AttackResults array' {
            $result.AttackResults | Should -HaveCount 0
        }
    }

    Context 'Output object has all expected properties' {
        BeforeAll {
            $propNames = (ConvertTo-PSRedTeamResult -Result ([PSCustomObject]@{
                Verdict='Pass'; Passed=$true; OverallScore=100.0; AttackSuccessRate=0.0
                TotalProbes=1; ResistedProbes=1; SucceededProbes=0; InconclusiveProbes=0
                StartedAt=[System.DateTimeOffset]::UtcNow; CompletedAt=[System.DateTimeOffset]::UtcNow
                Duration=[System.TimeSpan]::Zero; AgentName='ClaudeAgent'; Summary='OK'
                AttackResults=@(); FailedAttacks=@()
            }) -Model 'claude-opus-4-7').PSObject.Properties.Name
        }

        It 'Has property <_>' -ForEach @(
            'Verdict', 'Passed', 'OverallScore', 'AttackSuccessRate',
            'TotalProbes', 'ResistedProbes', 'SucceededProbes', 'InconclusiveProbes',
            'StartedAt', 'CompletedAt', 'Duration', 'AgentName',
            'Summary', 'FailedAttackNames', 'AttackResults'
        ) {
            $propNames | Should -Contain $_
        }
    }
}
