#Requires -Version 5.1
<#
.SYNOPSIS
    Builds both agent adapters from the shared source in this repository.

.DESCRIPTION
    The repository has exactly one authored copy of every skill, runbook, agent, command and policy
    document, under shared/. This script turns that single copy into two installable adapters:

        adapters/claude-code/   a Claude Code plugin
        adapters/opencode/      an OpenCode project configuration

    Nothing in adapters/ is hand-edited. Re-run this script after any change under shared/.

    What is generated rather than copied:

      * Permission rules. shared/policy/tool-names.json is the only place the tool inventory lives.
        Claude Code wants mcp__<server>__<tool> rules with deny/ask/allow arrays; OpenCode wants an
        ordered array of { action, resource, effect } objects where the last match wins. The shapes
        are not compatible, so both are generated here from the one inventory.

      * Agent frontmatter. shared/agents/*.md carries neutral fields (name, description, mode,
        read_only). Each host needs a different expression of the same intent: Claude Code uses a
        `tools:` allowlist, OpenCode uses a `permissions:` array.

      * Paths. Shared documents refer to sibling folders as shared/runbooks/, shared/policy/ and so
        on. Inside an installed adapter those folders sit at the adapter root and the runbooks are
        expected in the consuming repo under fabric/. The rewrite table below is the only place that
        mapping is written down.

.PARAMETER PluginName
    The Claude Code plugin name. It appears in every generated MCP tool name, so changing it changes
    every permission rule. Only change it before the first install.

.PARAMETER MarketplaceName
    The name of the marketplace emitted at .claude-plugin/marketplace.json.

.PARAMETER Version
    Plugin version written to plugin.json.

.PARAMETER SkipValidate
    Skip `claude plugin validate`, which otherwise runs when the Claude CLI is on PATH.

.EXAMPLE
    pwsh ./scripts/build.ps1

.EXAMPLE
    pwsh ./scripts/build.ps1 -SkipValidate
#>
[CmdletBinding()]
param(
    [string] $PluginName      = 'fabric-accelerator-agents',
    [string] $MarketplaceName = 'fabric-accelerator-agents',
    [string] $Version         = '0.1.0',
    [switch] $SkipValidate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$SharedDir   = Join-Path $RepoRoot 'shared'
$AdaptersDir = Join-Path $RepoRoot 'adapters'
$ClaudeDir   = Join-Path $AdaptersDir 'claude-code'
$OpenCodeDir = Join-Path $AdaptersDir 'opencode'

# ---------------------------------------------------------------------------------------------
# Path rewriting
#
# Authored documents point at the maintainer layout. Delivered documents must point at the layout
# an installed adapter actually has. Every difference is listed here and nowhere else.
# ---------------------------------------------------------------------------------------------
$PathRewrites = [ordered]@{
    'shared/runbooks/' = 'fabric/runbooks/'
    'shared/config/'   = 'fabric/'
    'shared/policy/'   = 'policy/'
    'shared/skills/'   = 'skills/'
    'shared/agents/'   = 'agents/'
    'shared/commands/' = 'commands/'
}

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

function Write-Utf8 {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Content
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $normalised = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $normalised, [System.Text.UTF8Encoding]::new($false))
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)] $Object
    )
    Write-Utf8 -Path $Path -Content ((Format-JsonValue -Value $Object -Indent 0) + "`n")
}

<#
    Windows PowerShell 5.1's ConvertTo-Json indents unpredictably, so generated configuration files
    are serialised here instead. Output is 2-space indented, keys keep their insertion order, and
    the result is re-parsed by ConvertFrom-Json during validation before the build is allowed to
    succeed.
#>
function Format-JsonString {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Value)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '"') { [void]$sb.Append('\"') }
        elseif ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($ch -eq "`n") { [void]$sb.Append('\n') }
        elseif ($ch -eq "`r") { [void]$sb.Append('\r') }
        elseif ($ch -eq "`t") { [void]$sb.Append('\t') }
        elseif ([int]$ch -lt 32) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Format-JsonValue {
    param(
        $Value,
        [int] $Indent
    )

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) { return (Format-JsonString $Value) }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $Value)
    }

    $innerPad = ' ' * ($Indent + 2)
    $outerPad = ' ' * $Indent

    if ($Value -is [System.Collections.IDictionary]) {
        $parts = @()
        foreach ($key in $Value.Keys) {
            $parts += $innerPad + (Format-JsonString ([string]$key)) + ': ' + (Format-JsonValue -Value $Value[$key] -Indent ($Indent + 2))
        }
        if ($parts.Count -eq 0) { return '{}' }
        return "{`n" + ($parts -join ",`n") + "`n" + $outerPad + '}'
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = @()
        foreach ($item in $Value) {
            $parts += $innerPad + (Format-JsonValue -Value $item -Indent ($Indent + 2))
        }
        if ($parts.Count -eq 0) { return '[]' }
        return "[`n" + ($parts -join ",`n") + "`n" + $outerPad + ']'
    }

    throw "Cannot serialise a value of type $($Value.GetType().FullName)."
}

function Read-TextFile {
    param([Parameter(Mandatory)][string] $Path)
    # Explicit UTF8 matters: Windows PowerShell 5.1 otherwise decodes these files as ANSI and turns
    # every em dash and arrow into mojibake before it is written back out.
    (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) -replace "`r`n", "`n"
}

function Convert-SharedPaths {
    param([Parameter(Mandatory)][string] $Text)
    foreach ($pair in $PathRewrites.GetEnumerator()) {
        $Text = $Text.Replace($pair.Key, $pair.Value)
    }
    return $Text
}

function Copy-SharedDocument {
    param(
        [Parameter(Mandatory)][string] $Source,
        [Parameter(Mandatory)][string] $Destination
    )
    Write-Utf8 -Path $Destination -Content (Convert-SharedPaths (Read-TextFile $Source))
}

<#
    Splits a markdown file into its YAML frontmatter (a flat key/value map — every authored agent
    and command uses only scalars) and the body.
#>
function Read-MarkdownFile {
    param([Parameter(Mandatory)][string] $Path)

    $lines = (Read-TextFile $Path) -split "`n"
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
        throw "Missing YAML frontmatter: $Path"
    }

    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $end = $i; break }
    }
    if ($end -lt 0) { throw "Unterminated YAML frontmatter: $Path" }

    $meta = [ordered]@{}
    for ($i = 1; $i -lt $end; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $sep = $line.IndexOf(':')
        if ($sep -lt 1) { throw "Unparseable frontmatter line in $Path : $line" }
        $key   = $line.Substring(0, $sep).Trim()
        $value = $line.Substring($sep + 1).Trim()
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $meta[$key] = $value
    }

    $bodyLines = if ($end + 1 -lt $lines.Count) { $lines[($end + 1)..($lines.Count - 1)] } else { @() }
    $body = ($bodyLines -join "`n").TrimStart("`n")

    return [pscustomobject]@{ Meta = $meta; Body = $body }
}

function Format-YamlString {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Value)
    '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function New-PermissionRule {
    param(
        [Parameter(Mandatory)][string] $Action,
        [Parameter(Mandatory)][string] $Resource,
        [Parameter(Mandatory)][ValidateSet('allow', 'ask', 'deny')][string] $Effect
    )
    [ordered]@{ action = $Action; resource = $Resource; effect = $Effect }
}

# ---------------------------------------------------------------------------------------------
# Load the canonical tool inventory
# ---------------------------------------------------------------------------------------------

$specPath = Join-Path $SharedDir 'policy/tool-names.json'
if (-not (Test-Path -LiteralPath $specPath)) { throw "Missing tool inventory: $specPath" }
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json

$CoreServerName = 'fabric-core'
$LocalServerName = 'fabric-local'

$core = $spec.servers.$CoreServerName
$local = $spec.servers.$LocalServerName

if ($null -eq $core -or $null -eq $local) { throw 'tool-names.json must declare fabric-core and fabric-local.' }

$coreRead    = @($core.read)
$coreWrite   = @($core.write)
$coreDelete  = @($core.delete)
$localRead   = @($local.read)
$roleChanges = @($spec.roleChangeTools)

# Guard against the inventory silently losing its guardrail coverage.
if ($coreDelete.Count -eq 0) { throw 'tool-names.json declares no delete tools; refusing to generate permissive rules.' }
if ($roleChanges.Count -eq 0) { throw 'tool-names.json declares no role-change tools.' }
foreach ($tool in $roleChanges) {
    if ($coreWrite -notcontains $tool -and $coreDelete -notcontains $tool) {
        throw "Role-change tool '$tool' is not listed under write or delete in tool-names.json."
    }
}

<#
    Claude Code MCP tool names for a plugin-bundled server are
    mcp__plugin_<plugin-name>_<server-name>__<tool-name>. Hyphens survive; other characters do not.
    This prefix is why the plugin name is a build parameter rather than a constant buried in a file.
#>
function Get-ClaudeToolPrefix {
    param([Parameter(Mandatory)][string] $ServerName)
    "mcp__plugin_${PluginName}_${ServerName}__"
}

$claudeCorePrefix  = Get-ClaudeToolPrefix $CoreServerName
$claudeLocalPrefix = Get-ClaudeToolPrefix $LocalServerName

# OpenCode names a tool <server>_<tool>, keeping letters, digits, underscore and hyphen.
$ocCorePrefix  = "${CoreServerName}_"
$ocLocalPrefix = "${LocalServerName}_"

# ---------------------------------------------------------------------------------------------
# Rule sets
# ---------------------------------------------------------------------------------------------

<#
    Claude Code: three independent arrays evaluated deny -> ask -> allow, first match wins. A deny
    removes the tool from the model's context entirely, so the broadest safe deny goes in deny and
    is never "carved out" by a narrower allow.
#>
$claudeDeny = [System.Collections.Generic.List[string]]::new()
$claudeAsk  = [System.Collections.Generic.List[string]]::new()
$claudeAllow = [System.Collections.Generic.List[string]]::new()

foreach ($tool in $coreDelete) { $claudeDeny.Add("$claudeCorePrefix$tool") }
$claudeDeny.Add("${claudeCorePrefix}delete_*")

foreach ($tool in $coreWrite) {
    if ($coreDelete -contains $tool) { continue }
    $claudeAsk.Add("$claudeCorePrefix$tool")
}

foreach ($tool in $coreRead) { $claudeAllow.Add("$claudeCorePrefix$tool") }
foreach ($tool in $localRead) { $claudeAllow.Add("$claudeLocalPrefix$tool") }

<#
    OpenCode: one ordered array, last match wins. Broad rules first, specific rules last. This is
    the inverse of the intuitive order and the reason these rules are generated rather than typed.
#>
$openCodeRules = [System.Collections.Generic.List[object]]::new()
$openCodeRules.Add((New-PermissionRule -Action 'shell' -Resource '*' -Effect 'ask'))
$openCodeRules.Add((New-PermissionRule -Action "$ocCorePrefix*" -Resource '*' -Effect 'ask'))
foreach ($tool in $coreDelete) {
    $openCodeRules.Add((New-PermissionRule -Action "$ocCorePrefix$tool" -Resource '*' -Effect 'deny'))
}
$openCodeRules.Add((New-PermissionRule -Action "${ocCorePrefix}delete_*" -Resource '*' -Effect 'deny'))
$openCodeRules.Add((New-PermissionRule -Action "$ocLocalPrefix*" -Resource '*' -Effect 'ask'))
foreach ($tool in $localRead) {
    $openCodeRules.Add((New-PermissionRule -Action "$ocLocalPrefix$tool" -Resource '*' -Effect 'allow'))
}
foreach ($tool in $coreRead) {
    $openCodeRules.Add((New-PermissionRule -Action "$ocCorePrefix$tool" -Resource '*' -Effect 'allow'))
}

<#
    Read-only subagents, OpenCode form. Everything is denied, then the exact reads needed are
    allowed back in. Because last match wins, the deny must come first.
#>
$openCodeReadOnlyRules = [System.Collections.Generic.List[object]]::new()
$openCodeReadOnlyRules.Add((New-PermissionRule -Action '*' -Resource '*' -Effect 'deny'))
foreach ($action in @('read', 'glob', 'grep', 'skill')) {
    $openCodeReadOnlyRules.Add((New-PermissionRule -Action $action -Resource '*' -Effect 'allow'))
}
foreach ($tool in $coreRead) {
    $openCodeReadOnlyRules.Add((New-PermissionRule -Action "$ocCorePrefix$tool" -Resource '*' -Effect 'allow'))
}
foreach ($tool in $localRead) {
    $openCodeReadOnlyRules.Add((New-PermissionRule -Action "$ocLocalPrefix$tool" -Resource '*' -Effect 'allow'))
}

# ---------------------------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------------------------

if (Test-Path -LiteralPath $AdaptersDir) {
    Remove-Item -LiteralPath $AdaptersDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ClaudeDir, $OpenCodeDir -Force | Out-Null

$emitted = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------------------------------------
# Claude Code adapter
# ---------------------------------------------------------------------------------------------

Write-JsonFile -Path (Join-Path $ClaudeDir '.claude-plugin/plugin.json') -Object ([ordered]@{
    name        = $PluginName
    version     = $Version
    description = 'Guide-and-verify deployment of Microsoft Fabric environments: provisioning checklists, Git and deployment pipeline runbooks, read-only verification, drift checks, and guardrails for the official Fabric MCP servers.'
    author      = [ordered]@{ name = 'Fabric Accelerator maintainers' }
    license     = 'MIT'
    keywords    = @('fabric', 'deployment', 'guardrails', 'drift', 'verification', 'mcp')
})
$emitted.Add('claude-code/.claude-plugin/plugin.json')

<#
    The servers are bundled with the plugin, which is what makes the plugin-scoped tool names in
    the generated rules correct and removes the folder-trust requirement that a project-scope
    .mcp.json headersHelper would carry.
#>
Write-JsonFile -Path (Join-Path $ClaudeDir '.mcp.json') -Object ([ordered]@{
    mcpServers = [ordered]@{
        $CoreServerName = [ordered]@{
            type          = 'http'
            url           = $core.url
            headersHelper = 'node "${CLAUDE_PLUGIN_ROOT}/scripts/fabric-mcp-headers.mjs"'
        }
        $LocalServerName = [ordered]@{
            type    = 'stdio'
            command = $local.command
            args    = @($local.args)
        }
    }
})
$emitted.Add('claude-code/.mcp.json')

Write-JsonFile -Path (Join-Path $ClaudeDir 'settings.template.json') -Object ([ordered]@{
    permissions = [ordered]@{
        deny  = @($claudeDeny)
        ask   = @($claudeAsk)
        allow = @($claudeAllow)
    }
})
$emitted.Add('claude-code/settings.template.json')

$claudeAgentTools = @('Read', 'Grep', 'Glob')
foreach ($tool in $coreRead) { $claudeAgentTools += "$claudeCorePrefix$tool" }
foreach ($tool in $localRead) { $claudeAgentTools += "$claudeLocalPrefix$tool" }

$claudeAgentNames = @('verifier', 'drift-checker')
foreach ($agentName in $claudeAgentNames) {
    $source = Join-Path $SharedDir "agents/$agentName.md"
    $doc = Read-MarkdownFile $source
    if ($doc.Meta['read_only'] -ne 'true') {
        throw "Refusing to emit '$agentName' as a Claude Code subagent: it is not marked read_only."
    }
    $frontMatter = @(
        '---'
        "name: $agentName"
        "description: $(Format-YamlString $doc.Meta['description'])"
        "tools: $($claudeAgentTools -join ', ')"
        '---'
        ''
    ) -join "`n"
    Write-Utf8 -Path (Join-Path $ClaudeDir "agents/$agentName.md") -Content ($frontMatter + (Convert-SharedPaths $doc.Body) + "`n")
    $emitted.Add("claude-code/agents/$agentName.md")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'commands') -Filter '*.md' -File) {
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $ClaudeDir "commands/$($file.Name)")
    $emitted.Add("claude-code/commands/$($file.Name)")
}

foreach ($skillDir in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'skills') -Directory) {
    Copy-SharedDocument `
        -Source (Join-Path $skillDir.FullName 'SKILL.md') `
        -Destination (Join-Path $ClaudeDir "skills/$($skillDir.Name)/SKILL.md")
    $emitted.Add("claude-code/skills/$($skillDir.Name)/SKILL.md")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'runbooks') -Filter '*.md' -File) {
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $ClaudeDir "fabric/runbooks/$($file.Name)")
    $emitted.Add("claude-code/fabric/runbooks/$($file.Name)")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'config') -File) {
    $target = if ($file.Extension -eq '.yaml') { "fabric/$($file.Name)" } else { "fabric/$($file.Name)" }
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $ClaudeDir $target)
    $emitted.Add("claude-code/$target")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'policy') -File) {
    if ($file.Extension -ne '.md' -and $file.Name -ne 'tool-names.json') { continue }
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $ClaudeDir "policy/$($file.Name)")
    $emitted.Add("claude-code/policy/$($file.Name)")
}

Write-Utf8 -Path (Join-Path $ClaudeDir 'scripts/fabric-mcp-headers.mjs') -Content (Read-TextFile (Join-Path $PSScriptRoot 'fabric-mcp-headers.mjs'))
$emitted.Add('claude-code/scripts/fabric-mcp-headers.mjs')

Copy-SharedDocument -Source (Join-Path $RepoRoot 'AGENTS.md') -Destination (Join-Path $ClaudeDir 'AGENTS.md')
Copy-SharedDocument -Source (Join-Path $RepoRoot 'CLAUDE.md') -Destination (Join-Path $ClaudeDir 'CLAUDE.md')
$emitted.Add('claude-code/AGENTS.md')
$emitted.Add('claude-code/CLAUDE.md')

$claudeReadme = Join-Path $SharedDir 'adapters/claude-code.README.md'
if (Test-Path -LiteralPath $claudeReadme) {
    Copy-SharedDocument -Source $claudeReadme -Destination (Join-Path $ClaudeDir 'README.md')
    $emitted.Add('claude-code/README.md')
}

# ---------------------------------------------------------------------------------------------
# OpenCode adapter
# ---------------------------------------------------------------------------------------------

$openCodeConfig = [ordered]@{
    '$schema'     = 'https://opencode.ai/config.json'
    mcp           = [ordered]@{
        servers = [ordered]@{
            $CoreServerName = [ordered]@{
                type     = 'remote'
                url      = $core.url
                oauth    = $false
                codemode = $false
                headers  = [ordered]@{ Authorization = 'Bearer {env:FABRIC_MCP_TOKEN}' }
            }
            $LocalServerName = [ordered]@{
                type     = 'local'
                command  = @($local.command) + @($local.args)
                codemode = $false
            }
        }
    }
    permissions   = @($openCodeRules)
}
Write-JsonFile -Path (Join-Path $OpenCodeDir 'opencode.json') -Object $openCodeConfig
$emitted.Add('opencode/opencode.json')

function Format-PermissionYaml {
    param([Parameter(Mandatory)] $Rules)
    $lines = @('permissions:')
    foreach ($rule in $Rules) {
        $lines += "  - action: $(Format-YamlString $rule.action)"
        $lines += "    resource: $(Format-YamlString $rule.resource)"
        $lines += "    effect: $($rule.effect)"
    }
    return ($lines -join "`n")
}

foreach ($agentName in @('verifier', 'drift-checker')) {
    $doc = Read-MarkdownFile (Join-Path $SharedDir "agents/$agentName.md")
    if ($doc.Meta['read_only'] -ne 'true') {
        throw "Refusing to emit '$agentName' as an OpenCode subagent: it is not marked read_only."
    }
    $frontMatter = @(
        '---'
        "description: $(Format-YamlString $doc.Meta['description'])"
        'mode: subagent'
        (Format-PermissionYaml $openCodeReadOnlyRules)
        '---'
        ''
    ) -join "`n"
    Write-Utf8 -Path (Join-Path $OpenCodeDir ".opencode/agents/$agentName.md") -Content ($frontMatter + (Convert-SharedPaths $doc.Body) + "`n")
    $emitted.Add("opencode/.opencode/agents/$agentName.md")
}

$primaryDoc = Read-MarkdownFile (Join-Path $SharedDir 'agents/fabric-deployer.md')
if ($primaryDoc.Meta['read_only'] -ne 'false') {
    throw "The primary agent must be marked read_only: false."
}
$primaryFrontMatter = @(
    '---'
    "description: $(Format-YamlString $primaryDoc.Meta['description'])"
    'mode: primary'
    (Format-PermissionYaml $openCodeRules)
    '---'
    ''
) -join "`n"
Write-Utf8 -Path (Join-Path $OpenCodeDir '.opencode/agents/fabric-deployer.md') -Content ($primaryFrontMatter + (Convert-SharedPaths $primaryDoc.Body) + "`n")
$emitted.Add('opencode/.opencode/agents/fabric-deployer.md')

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'commands') -Filter '*.md' -File) {
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $OpenCodeDir ".opencode/commands/$($file.Name)")
    $emitted.Add("opencode/.opencode/commands/$($file.Name)")
}

foreach ($skillDir in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'skills') -Directory) {
    Copy-SharedDocument `
        -Source (Join-Path $skillDir.FullName 'SKILL.md') `
        -Destination (Join-Path $OpenCodeDir ".opencode/skills/$($skillDir.Name)/SKILL.md")
    $emitted.Add("opencode/.opencode/skills/$($skillDir.Name)/SKILL.md")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'runbooks') -Filter '*.md' -File) {
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $OpenCodeDir "fabric/runbooks/$($file.Name)")
    $emitted.Add("opencode/fabric/runbooks/$($file.Name)")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'config') -File) {
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $OpenCodeDir "fabric/$($file.Name)")
    $emitted.Add("opencode/fabric/$($file.Name)")
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $SharedDir 'policy') -File) {
    if ($file.Extension -ne '.md' -and $file.Name -ne 'tool-names.json') { continue }
    Copy-SharedDocument -Source $file.FullName -Destination (Join-Path $OpenCodeDir "policy/$($file.Name)")
    $emitted.Add("opencode/policy/$($file.Name)")
}

Copy-SharedDocument -Source (Join-Path $RepoRoot 'AGENTS.md') -Destination (Join-Path $OpenCodeDir 'AGENTS.md')
$emitted.Add('opencode/AGENTS.md')

$openCodeReadme = Join-Path $SharedDir 'adapters/opencode.README.md'
if (Test-Path -LiteralPath $openCodeReadme) {
    Copy-SharedDocument -Source $openCodeReadme -Destination (Join-Path $OpenCodeDir 'README.md')
    $emitted.Add('opencode/README.md')
}

# ---------------------------------------------------------------------------------------------
# Marketplace
# ---------------------------------------------------------------------------------------------

Write-JsonFile -Path (Join-Path $RepoRoot '.claude-plugin/marketplace.json') -Object ([ordered]@{
    name    = $MarketplaceName
    owner   = [ordered]@{ name = 'Fabric Accelerator maintainers' }
    plugins = @(
        [ordered]@{
            name        = $PluginName
            source      = './adapters/claude-code'
            description = 'Guide-and-verify deployment of Microsoft Fabric environments with official MCP servers, read-only subagents and generated guardrails.'
            version     = $Version
        }
    )
})
$emitted.Add('.claude-plugin/marketplace.json')

# ---------------------------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------------------------

$jsonFiles = @(Get-ChildItem -LiteralPath $AdaptersDir -Recurse -File -Filter '*.json' |
    Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' })
$jsonFiles += Get-Item -LiteralPath (Join-Path $RepoRoot '.claude-plugin/marketplace.json')

foreach ($file in $jsonFiles) {
    try {
        Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Generated JSON does not parse: $($file.FullName) - $($_.Exception.Message)"
    }
}

# Every guardrail this toolkit claims to enforce must appear in both generated rule sets.
foreach ($tool in $coreDelete) {
    if ($claudeDeny -notcontains "$claudeCorePrefix$tool") { throw "Claude rules lost the deny for $tool." }
    $expected = "$ocCorePrefix$tool"
    if (-not ($openCodeRules | Where-Object { $_.action -eq $expected -and $_.effect -eq 'deny' })) {
        throw "OpenCode rules lost the deny for $tool."
    }
}
foreach ($tool in $coreRead) {
    if ($claudeAllow -notcontains "$claudeCorePrefix$tool") { throw "Claude rules lost the allow for $tool." }
    $expected = "$ocCorePrefix$tool"
    if (-not ($openCodeRules | Where-Object { $_.action -eq $expected -and $_.effect -eq 'allow' })) {
        throw "OpenCode rules lost the allow for $tool."
    }
}

if (-not $SkipValidate -and (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host 'Running claude plugin validate ...'
    & claude plugin validate $ClaudeDir
    if ($LASTEXITCODE -ne 0) { throw "claude plugin validate failed with exit code $LASTEXITCODE." }
}
elseif (-not $SkipValidate) {
    Write-Host 'claude CLI not found on PATH; skipping plugin validation.'
}

Write-Host ''
Write-Host "Built $($emitted.Count) files from shared/ using plugin name '$PluginName'."
Write-Host ''
Write-Host "  MCP tools guarded: $($coreRead.Count) read allow, $($coreDelete.Count) delete deny, $($coreWrite.Count) write ask"
Write-Host "  Claude prefix:    $claudeCorePrefix"
Write-Host "  OpenCode prefix:  $ocCorePrefix"
Write-Host ''
$emitted | Sort-Object | ForEach-Object { Write-Host "  $_" }
