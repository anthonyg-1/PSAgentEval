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
        # .GetAwaiter().GetResult() wraps the real exception in a MethodInvocationException;
        # peel it off so the message shows the Anthropic error, not the PowerShell wrapper.
        $inner  = $_.Exception.InnerException
        $msg    = if ($null -ne $inner) { $inner.Message } else { $_.Exception.Message }
        $source = if ($null -ne $inner) { $inner } else { $_.Exception }
        $ex  = [System.UnauthorizedAccessException]::new(
            "API key validation failed: $msg", $source)
        $err = [System.Management.Automation.ErrorRecord]::new(
            $ex, 'InvalidApiKey',
            [System.Management.Automation.ErrorCategory]::AuthenticationError, $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }
}
