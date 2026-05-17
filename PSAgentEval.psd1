@{
    RootModule        = 'PSAgentEval.psm1'
    ModuleVersion     = '0.1.3'
    GUID              = 'a7d4e2b1-3f86-4c91-b5d7-9e1a2c3f0d85'
    Author            = 'Anthony Guimelli'
    Description       = 'PowerShell script module wrapping AgentEval red team security evaluation for Claude AI agents.'
    PowerShellVersion = '7.5.0'
    FunctionsToExport = @('Invoke-AgentRedTeam')
    CmdletsToExport   = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags       = @('AI', 'Security', 'RedTeam', 'Claude', 'Anthropic', 'LLM')
            ProjectUri = 'https://github.com/AgentEvalHQ/AgentEval'
        }
    }
}
