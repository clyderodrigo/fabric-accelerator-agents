#Requires -Version 5.1
<#
.SYNOPSIS
    Rewrites tenant-specific connection GUIDs in Fabric item definitions.

.DESCRIPTION
    Fabric pipelines and MirroredDatabases bind a connection through a plain
    "connection": "<guid>" string. That field is not an expression slot, so a
    Variable Library value cannot be substituted into it, and the GUIDs shipped
    in this repository are the ones from the original tenant. On any other tenant
    those GUIDs do not exist, so Git sync fails with RequestValidationFailed /
    ConnectionNotAccessible before the item is even created.

    This script performs the per-tenant rebind that runbook 04 calls "Option B -
    parameterise (not available here) / Option A - deployment rule (not
    available for this property)". It is the only way to make these definitions
    portable, and it is a file edit in the repo, never a tenant mutation.

    It reads a mapping file of { "<old guid>": "<new guid>" } pairs and replaces
    every occurrence in the JSON definitions under the supplied roots. It does
    not touch .platform files or logicalIds.

.PARAMETER MappingFile
    Path to a JSON file mapping source-tenant connection GUIDs to target-tenant
    connection GUIDs. See fabric/connection-rebind.example.json.

.PARAMETER Roots
    One or more folders to scan. Defaults to dateng, dateng-optional, dateng-rti.

.PARAMETER DryRun
    Print what would change without writing anything.

.EXAMPLE
    pwsh ./scripts/rebind-connections.ps1 -MappingFile ./fabric/connection-rebind.json

.EXAMPLE
    pwsh ./scripts/rebind-connections.ps1 -MappingFile ./fabric/connection-rebind.json -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $MappingFile,
    [string[]] $Roots = @('dateng', 'dateng-optional', 'dateng-rti'),
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ResolvedMapping = if ([System.IO.Path]::IsPathRooted($MappingFile)) { $MappingFile } else { Join-Path (Get-Location) $MappingFile }
if (-not (Test-Path -LiteralPath $ResolvedMapping)) { throw "Mapping file not found: $ResolvedMapping" }

$mapping = Get-Content -LiteralPath $ResolvedMapping -Raw | ConvertFrom-Json
$pairs = @{}
foreach ($prop in $mapping.PSObject.Properties) {
    $old = $prop.Name
    $new = [string]$prop.Value
    if ($old -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        throw "Mapping key is not a GUID: $old"
    }
    if ($new -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        throw "Mapping value is not a GUID: $new  (key $old)"
    }
    $pairs[$old] = $new
}
if ($pairs.Count -eq 0) { throw "Mapping file contains no pairs." }

Write-Host "Loaded $($pairs.Count) rebind pair(s)."
$pairs.GetEnumerator() | Sort-Object Key | ForEach-Object { Write-Host "  $($_.Key) -> $($_.Value)" }

$filesChanged = 0
$totalReplacements = 0
foreach ($root in $Roots) {
    $rootPath = if ([System.IO.Path]::IsPathRooted($root)) { $root } else { Join-Path $RepoRoot $root }
    if (-not (Test-Path -LiteralPath $rootPath)) { continue }
    Get-ChildItem -LiteralPath $rootPath -Recurse -File -Filter '*.json' | ForEach-Object {
        $path = $_.FullName
        $original = [System.IO.File]::ReadAllText($path)
        $updated = $original
        $fileCount = 0
        foreach ($old in $pairs.Keys) {
            $new = $pairs[$old]
            $occurrences = ([regex]::Matches($updated, [regex]::Escape($old))).Count
            if ($occurrences -gt 0) {
                $updated = $updated.Replace($old, $new)
                $fileCount += $occurrences
            }
        }
        if ($fileCount -gt 0) {
            $rel = $path.Substring($RepoRoot.Length + 1)
            Write-Host "$rel : $fileCount replacement(s)"
            if (-not $DryRun) {
                [System.IO.File]::WriteAllText($path, $updated, [System.Text.UTF8Encoding]::new($false))
            }
            $filesChanged++
            $totalReplacements += $fileCount
        }
    }
}

Write-Host ""
Write-Host "Files touched : $filesChanged"
Write-Host "Replacements  : $totalReplacements"
if ($DryRun) { Write-Host "DRY RUN - no files were written." }
