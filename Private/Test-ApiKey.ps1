function Test-ApiKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    try {
        $auth   = [Anthropic.SDK.APIAuthentication]::new($ApiKey)
        $client = [Anthropic.SDK.AnthropicClient]::new($auth, $null, $null)
        $opts   = [Microsoft.Extensions.AI.ChatOptions]::new()
        $opts.ModelId         = 'claude-haiku-4-5-20251001'
        $opts.MaxOutputTokens = 1

        $msgs = [System.Collections.Generic.List[Microsoft.Extensions.AI.ChatMessage]]::new()
        $msgs.Add([Microsoft.Extensions.AI.ChatMessage]::new(
            [Microsoft.Extensions.AI.ChatRole]::User, '.'))

        $client.Messages.CompleteAsync(
            $msgs, $opts, [System.Threading.CancellationToken]::None
        ).GetAwaiter().GetResult() | Out-Null
    }
    catch {
        $ex  = [System.UnauthorizedAccessException]::new(
            "API key validation failed: $($_.Exception.Message)", $_.Exception)
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'InvalidApiKey',
            [System.Management.Automation.ErrorCategory]::AuthenticationError, $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }
}
