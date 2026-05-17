function Invoke-AgentRedTeam {
    <#
    .SYNOPSIS
        Runs automated red team security evaluation against a Claude AI agent and returns the results as a PSObject.

    .DESCRIPTION
        Invoke-AgentRedTeam sends up to 192 pre-written adversarial probes across 9 attack categories to the target Claude model and evaluates whether each probe was resisted or succeeded. The results are returned as a structured PSObject suitable for piping, filtering, or export.

        Attack categories covered: Prompt Injection, Jailbreak, PII Leakage, System Prompt Extraction, Indirect Injection, Excessive Agency, Insecure Output Handling, Inference API Abuse, and Encoding Evasion. Coverage maps to 6 of 10 OWASP LLM Top 10 2025 categories and 6 MITRE ATLAS technique IDs.

        The Anthropic API key is read from the ANTHROPIC_API_KEY environment variable if -ApiKey is not provided.

    .PARAMETER ApiKey
        Anthropic API key used to call the model under test. Defaults to the value of the ANTHROPIC_API_KEY environment variable. The command terminates with an error if neither is set.

    .PARAMETER Model
        The Claude model ID to evaluate. Defaults to claude-opus-4-7. Any model supported by the Anthropic Messages API is accepted (e.g. claude-sonnet-4-6, claude-haiku-4-5-20251001).

    .PARAMETER SystemPrompt
        The system prompt given to the agent under test. This defines the agent's persona and constraints. Use the same system prompt your agent uses in production to get meaningful results. Defaults to "You are a helpful AI assistant."

    .PARAMETER Intensity
        Controls how many probes are sent per attack category. Accepted values:

          Quick         -- Fastest scan, subset of probes per attack. Estimated cost: $0.01-$0.03.
          Moderate      -- Balanced depth. Estimated cost: $0.05-$0.10.
          Comprehensive -- All probes across all attacks. Up to 192 probes. Estimated cost: $0.10-$0.30.

        Defaults to Quick.

    .PARAMETER RateLimitMs
        Milliseconds to wait between probe requests. Increase this value if you are hitting Anthropic API rate limits. Defaults to 100.

    .PARAMETER FailFast
        When specified, the scan stops immediately after the first successful attack probe. Useful in CI pipelines where you only need a pass/fail signal quickly.

    .OUTPUTS
        PSObject

        A PSObject with the following properties:
          Verdict            -- Pass, PartialPass, Fail, or Inconclusive.
          Passed             -- Boolean. True only when Verdict is Pass.
          OverallScore       -- Double 0-100. Percentage of probes resisted (higher is better).
          AttackSuccessRate  -- Double 0-1. Fraction of probes that succeeded (lower is better).
          TotalProbes        -- Total number of probes sent.
          ResistedProbes     -- Number of probes the agent defended against.
          SucceededProbes    -- Number of probes that exposed a vulnerability.
          InconclusiveProbes -- Number of probes with indeterminate outcome.
          StartedAt          -- DateTimeOffset when the scan began.
          CompletedAt        -- DateTimeOffset when the scan ended.
          Duration           -- TimeSpan for the total scan.
          Model              -- The Claude model ID that was evaluated.
          AgentName          -- Name of the agent under test.
          Summary            -- Human-readable summary paragraph.
          FailedAttackNames  -- String[] of attack categories that were not fully resisted.
          AttackResults      -- PSObject[] with per-attack breakdown including a Probes array.

    .EXAMPLE
        $env:ANTHROPIC_API_KEY = 'sk-ant-...'
        $result = Invoke-AgentRedTeam -SystemPrompt "You are a customer support bot for Contoso."
        $result.Verdict
        $result.OverallScore

        Runs a Quick scan (fastest, lowest cost) against claude-opus-4-7 with a custom system prompt. The API key is picked up from the environment variable. Verdict and score are printed.

    .EXAMPLE
        $result = Invoke-AgentRedTeam `
            -ApiKey  'sk-ant-...' `
            -Model   'claude-sonnet-4-6' `
            -SystemPrompt "You are a helpful AI assistant." `
            -Intensity Quick

        Evaluates claude-sonnet-4-6 explicitly, providing the API key inline. Useful when running multiple scans against different models in the same session.

    .EXAMPLE
        $result = Invoke-AgentRedTeam -Intensity Moderate -SystemPrompt "You are a financial advisor bot."

        if (-not $result.Passed) {
            Write-Warning "Agent failed: $($result.Verdict) (score $($result.OverallScore))"
            $result.AttackResults |
                Where-Object { -not $_.Passed } |
                Select-Object AttackName, SucceededProbes, AttackSuccessRate |
                Format-Table -AutoSize
        }

        Runs a Moderate scan and, if the agent did not pass, prints a table of the failed attack categories with their probe counts and success rates.

    .EXAMPLE
        $result = Invoke-AgentRedTeam -Intensity Comprehensive -RateLimitMs 500

        $result.AttackResults |
            ForEach-Object { $_.Probes } |
            Where-Object { $_.Outcome -eq 'Succeeded' -and $_.Severity -in 'High','Critical' } |
            Select-Object ProbeId, Severity, Technique, Prompt, Response |
            Format-List

        Runs a full Comprehensive scan with a slower request rate (500 ms between probes) to avoid rate limiting. After the scan, all probe failures rated High or Critical are displayed with the exact prompt sent and the agent's response.

    .EXAMPLE
        $result = Invoke-AgentRedTeam -Intensity Quick -FailFast

        if (-not $result.Passed) {
            Write-Error "Red team gate failed -- $($result.FailedAttackNames -join ', ')"
            exit 1
        }

        Designed for a CI step. The scan stops on the first vulnerability found (-FailFast), minimising API cost. A non-zero exit code signals pipeline failure.

    .EXAMPLE
        Invoke-AgentRedTeam -Intensity Moderate |
            ConvertTo-Json -Depth 10 |
            Set-Content -Path "redteam-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

        Pipes the PSObject directly into ConvertTo-Json for a full structured export. The -Depth 10 flag ensures nested probe detail is not truncated. The file is timestamped so repeated runs do not overwrite each other.

    .LINK
        https://github.com/AgentEvalHQ/AgentEval

    .LINK
        https://owasp.org/www-project-top-10-for-large-language-model-applications/
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter()]
        [string]$ApiKey = $env:ANTHROPIC_API_KEY,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Model = 'claude-opus-4-7',

        [Parameter()]
        [string]$SystemPrompt = 'You are a helpful AI assistant.',

        [Parameter()]
        [ValidateSet('Quick', 'Moderate', 'Comprehensive')]
        [string]$Intensity = 'Quick',

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$RateLimitMs = 100,

        [Parameter()]
        [switch]$FailFast
    )

    if ([string]::IsNullOrEmpty($ApiKey)) {
        $ex  = [System.ArgumentException]::new('Provide -ApiKey or set $env:ANTHROPIC_API_KEY.')
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'MissingApiKey',
            [System.Management.Automation.ErrorCategory]::InvalidArgument, $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }

    try {
        Test-ApiKey -ApiKey $ApiKey
    }
    catch {
        $err = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception, 'InvalidApiKey',
            [System.Management.Automation.ErrorCategory]::AuthenticationError, $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }

    Write-Progress -Activity 'Invoke-AgentRedTeam' `
                   -Status "Running $Intensity scan against $Model..." `
                   -PercentComplete -1

    try {
        # Build the agent under test
        $auth       = [Anthropic.SDK.APIAuthentication]::new($ApiKey)
        $client     = [Anthropic.SDK.AnthropicClient]::new($auth, $null, $null)
        $chatOpts   = [Microsoft.Extensions.AI.ChatOptions]::new()
        $chatOpts.ModelId = $Model
        $adapter    = [AgentEval.Core.ChatClientAgentAdapter]::new(
            $client.Messages, 'ClaudeAgent', $SystemPrompt, $chatOpts, $false)

        # Map intensity
        $intensityValue = switch ($Intensity) {
            'Moderate'      { [AgentEval.RedTeam.Intensity]::Moderate }
            'Comprehensive' { [AgentEval.RedTeam.Intensity]::Comprehensive }
            default         { [AgentEval.RedTeam.Intensity]::Quick }
        }

        # Configure and run the scan
        $options = [AgentEval.RedTeam.ScanOptions]::new()
        $options.AttackTypes            = [AgentEval.RedTeam.Attack]::All
        $options.Intensity              = $intensityValue
        $options.DelayBetweenProbes     = [System.TimeSpan]::FromMilliseconds($RateLimitMs)
        $options.FailFast               = $FailFast.IsPresent
        $options.IncludeEvidence        = $true
        $options.ProgressReportInterval = 1

        # Wire up the relay: a LINQ expression tree compiles a real Action<ScanProgress> delegate
        # (no ScriptBlock) so it runs safely on thread-pool threads. The main PS thread polls
        # relay.Pop() every 200 ms and calls Write-Progress without any cross-thread runspace issues.
        $relay      = [PSAgentEvalProgressRelay]::new()
        $pushMethod = [PSAgentEvalProgressRelay].GetMethod('Push')
        $paramExpr  = [System.Linq.Expressions.Expression]::Parameter([AgentEval.RedTeam.ScanProgress], 'p')
        $boxedExpr  = [System.Linq.Expressions.Expression]::Convert($paramExpr, [object])
        $callExpr   = [System.Linq.Expressions.Expression]::Call(
                          [System.Linq.Expressions.Expression]::Constant($relay), $pushMethod, $boxedExpr)
        $plist = [System.Collections.Generic.List[System.Linq.Expressions.ParameterExpression]]::new()
        $plist.Add($paramExpr)
        $lambda = [System.Linq.Expressions.Expression]::Lambda(
                      [System.Action[AgentEval.RedTeam.ScanProgress]], $callExpr, $plist)
        $options.OnProgress = $lambda.Compile()

        $runner = [AgentEval.RedTeam.RedTeamRunner]::new()
        $task   = $runner.ScanAsync($adapter, $options, [System.Threading.CancellationToken]::None)

        $last = $null
        while (-not $task.IsCompleted) {
            $item = $relay.Pop()
            if ($null -ne $item) { $last = $item }
            if ($last) {
                $eta = if ($null -ne $last.EstimatedRemaining) {
                    "  ETA $([math]::Round($last.EstimatedRemaining.TotalSeconds))s"
                }
                Write-Progress -Activity 'Invoke-AgentRedTeam' `
                               -Status "$($last.StatusEmoji) $($last.CurrentAttack) - resisted: $($last.ResistedCount)  failed: $($last.SucceededCount)$eta" `
                               -CurrentOperation "Probe $($last.CompletedProbes)/$($last.TotalProbes): $($last.CurrentProbe)" `
                               -PercentComplete ([int]$last.PercentComplete)
            }
            Start-Sleep -Milliseconds 200
        }

        $rawResult = $task.GetAwaiter().GetResult()

        ConvertTo-PSRedTeamResult -Result $rawResult -Model $Model
    }
    catch {
        if ($_.Exception -isnot [System.Management.Automation.PipelineStoppedException]) {
            $err = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception, 'RedTeamScanFailed',
                [System.Management.Automation.ErrorCategory]::OperationStopped, $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }
    }
    finally {
        Write-Progress -Activity 'Invoke-AgentRedTeam' -Completed
    }
}
