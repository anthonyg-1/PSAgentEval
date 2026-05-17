function ConvertTo-PSRedTeamResult {
    param(
        [Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][string]$Model
    )

    $attacks = $Result.AttackResults | ForEach-Object { ConvertTo-PSAttackResult $_ }

    [PSCustomObject]@{
        Verdict            = $Result.Verdict.ToString()
        Passed             = [bool]$Result.Passed
        OverallScore       = [double]$Result.OverallScore
        AttackSuccessRate  = [double]$Result.AttackSuccessRate
        TotalProbes        = [int]$Result.TotalProbes
        ResistedProbes     = [int]$Result.ResistedProbes
        SucceededProbes    = [int]$Result.SucceededProbes
        InconclusiveProbes = [int]$Result.InconclusiveProbes
        StartedAt          = $Result.StartedAt
        CompletedAt        = $Result.CompletedAt
        Duration           = $Result.Duration
        Model              = $Model
        AgentName          = $Result.AgentName
        Summary            = $Result.Summary
        FailedAttackNames  = @($Result.FailedAttacks | ForEach-Object { $_.AttackName })
        AttackResults      = @($attacks)
    }
}

function ConvertTo-PSAttackResult {
    param([Parameter(Mandatory)][object]$Attack)

    $probes = $Attack.ProbeResults | ForEach-Object { ConvertTo-PSProbeResult $_ }

    [PSCustomObject]@{
        AttackName         = $Attack.AttackName
        DisplayName        = $Attack.AttackDisplayName
        OwaspId            = $Attack.OwaspId
        MitreAtlasIds      = $Attack.MitreAtlasIds
        Passed             = [bool]$Attack.Passed
        AttackSuccessRate  = [double]$Attack.AttackSuccessRate
        TotalProbes        = [int]$Attack.TotalCount
        ResistedProbes     = [int]$Attack.ResistedCount
        SucceededProbes    = [int]$Attack.SucceededCount
        InconclusiveProbes = [int]$Attack.InconclusiveCount
        Severity           = $Attack.Severity.ToString()
        HighestSeverity    = $Attack.HighestSeverity.ToString()
        Probes             = @($probes)
    }
}

function ConvertTo-PSProbeResult {
    param([Parameter(Mandatory)][object]$Probe)

    [PSCustomObject]@{
        ProbeId      = $Probe.ProbeId
        Outcome      = $Probe.Outcome.ToString()
        Severity     = $Probe.Severity.ToString()
        Difficulty   = $Probe.Difficulty.ToString()
        Technique    = $Probe.Technique
        Prompt       = $Probe.Prompt
        Response     = $Probe.Response
        Reason       = $Probe.Reason
        MatchedItems = @(if ($null -ne $Probe.MatchedItems) { $Probe.MatchedItems })
        Duration     = $Probe.Duration
        HasError     = [bool]$Probe.HasError
        Error        = $Probe.Error
    }
}
