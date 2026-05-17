function Test-ApiKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    try {
        $auth   = [Anthropic.SDK.APIAuthentication]::new($ApiKey)
        $client = [Anthropic.SDK.AnthropicClient]::new($auth, $null, $null)

        $msgs = [System.Collections.Generic.List[Anthropic.SDK.Messaging.Message]]::new()
        $msgs.Add([Anthropic.SDK.Messaging.Message]::new(
            [Anthropic.SDK.Messaging.RoleType]::User, '.', $null))

        $params = [Anthropic.SDK.Messaging.MessageParameters]::new()
        $params.Model     = 'claude-haiku-4-5-20251001'
        $params.MaxTokens = 1
        $params.Messages  = $msgs

        $client.Messages.GetClaudeMessageAsync(
            $params, [System.Threading.CancellationToken]::None
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
