#Requires -Version 7.0

$libsPath = Join-Path $PSScriptRoot 'libs'

# Load all required assemblies explicitly in dependency order
$loadOrder = @(
    'System.Text.Encodings.Web.dll',
    'System.Text.Json.dll',
    'System.IO.Pipelines.dll',
    'System.Threading.Channels.dll',
    'Microsoft.Extensions.Primitives.dll',
    'Microsoft.Extensions.Logging.Abstractions.dll',
    'Microsoft.Extensions.DependencyInjection.Abstractions.dll',
    'Microsoft.Extensions.DependencyInjection.dll',
    'Microsoft.Extensions.Caching.Abstractions.dll',
    'Microsoft.Extensions.AI.Abstractions.dll',
    'Microsoft.Extensions.AI.dll',
    'Anthropic.SDK.dll',
    'AgentEval.Abstractions.dll',
    'AgentEval.Core.dll',
    'AgentEval.RedTeam.dll',
    'AgentEval.MAF.dll',
    'AgentEval.DataLoaders.dll',
    'AgentEval.dll'
)

foreach ($dll in $loadOrder) {
    $path = Join-Path $libsPath $dll
    if (Test-Path $path) {
        Add-Type -Path $path -ErrorAction SilentlyContinue
    }
}

# Compile a thread-safe progress relay so Write-Progress can be called from the main PS thread
# while the async scan runs on thread-pool threads (ScriptBlock delegates can't run without a runspace)
if (-not ('PSAgentEvalProgressRelay' -as [type])) {
    # Pure-BCL class, no AgentEval reference so no assembly-version conflicts.
    # The typed Action<ScanProgress> delegate is wired up via a LINQ expression tree in Invoke-AgentRedTeam.
    Add-Type -TypeDefinition @'
public sealed class PSAgentEvalProgressRelay {
    private volatile object _latest;
    public void Push(object value) { _latest = value; }
    public object Pop()  { var v = _latest; _latest = null; return v; }
}
'@ -ErrorAction Stop
}

# Dot-source private helpers first, then public functions
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function 'Invoke-AgentRedTeam'

# Emitted once per session from Invoke-AgentRedTeam so -WarningAction is respected.
$script:_previewWarningShown = $false
