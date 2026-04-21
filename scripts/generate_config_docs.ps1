$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$docsRepoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $docsRepoRoot
$docsRoot = Join-Path $docsRepoRoot "docs"
$generatedConfigRoot = Join-Path $docsRoot "generated\\configuration"
$flagsRoot = Join-Path $generatedConfigRoot "flags"
$scriptPath = Join-Path $workspaceRoot ".private\\scripts\\legacy-sync\\Sync-ConfiguredSqlTable.ps1"

$confirmedItems = @(
    "SyncId","SyncName","IsEnabled","SyncMode",
    "SourceServer","SourceDatabase","SourceSchema","SourceTable","SourceAuthMode","SourceUsername","SourcePassword",
    "DestinationServer","DestinationDatabase","DestinationSchema","DestinationTable","DestinationAuthMode","DestinationUsername","DestinationPassword",
    "CommandTimeoutSeconds","BatchSize","RetryCount","RetryDelaySeconds",
    "KeyColumnsCsv","ColumnsCsv","ExcludeColumnsCsv",
    "WatermarkColumn","WatermarkType","FullScanAllow","InsertOnly","MaxBatchesPerRun",
    "AutoCreateDestinationTable","CreatePrimaryKeyOnAutoCreate","ValidateDestinationSchema",
    "SourceWhereClause","PreSyncSql","PostSyncSql"
)

$overrides = @{
    "SyncMode" = @{
        Allowed = '`Incremental` or `FullRefresh`.'
        Default = 'Runtime default is `Incremental` when blank.'
        Effect = "Chooses incremental seek paging or full destination replacement."
        Risk = "high"
    }
    "KeyColumnsCsv" = @{
        Allowed = "Comma-separated key columns. Incremental mode currently requires exactly one key."
        Default = "Blank is not valid for incremental mode."
        Effect = "Defines seek paging and upsert join keys."
        Risk = "high"
    }
    "WatermarkColumn" = @{
        Allowed = 'Column name paired with `WatermarkType`.'
        Default = '`NULL` disables watermark paging.'
        Effect = "Enables watermark plus key paging."
        Risk = "high"
    }
    "WatermarkType" = @{
        Allowed = "Type string used by watermark conversion helpers."
        Default = '`NULL` disables watermark paging.'
        Effect = "Controls conversion of stored watermark state."
        Risk = "high"
    }
    "SourceWhereClause" = @{
        Allowed = 'SQL predicate fragment valid in `WHERE (...)` against the source object.'
        Default = "Blank means no extra filter."
        Effect = "Restricts source reads, counts, and snapshots."
        Risk = "high"
    }
    "PreSyncSql" = @{
        Allowed = "Destination-side T-SQL batch."
        Default = "Blank means skipped."
        Effect = "Runs before data movement begins."
        Risk = "high"
    }
    "PostSyncSql" = @{
        Allowed = "Destination-side T-SQL batch."
        Default = "Blank means skipped."
        Effect = "Runs after data movement completes."
        Risk = "high"
    }
    "BatchSize" = @{
        Allowed = "Positive integer. Tune it as a throughput-versus-memory control, not just a row-count setting."
        Default = "No database default confirmed; store explicitly."
        Effect = 'Changes both source `SELECT TOP (...)` read size and `SqlBulkCopy.BatchSize`.'
        Risk = "high"
        Dependencies = 'Review `SyncMode`, `SourceWhereClause`, source row width, large-value columns, and destination log throughput together before changing this field.'
        Examples = '`1000`, `5000`, `20000`'
        Scenario = 'Profile the source table first, choose a conservative value for wide rows or LOB data, then validate one controlled run before increasing further.'
        Troubleshooting = "If runs stall on one batch, spike memory, or hold long bulk-copy windows, lower this value and re-check the next run log."
    }
}

function Get-Slug {
    param([string]$Value)
    return (($Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '^-|-$', '')
}

function Get-TypeName {
    param([string]$Name)
    if ($Name -like "*Password") { return "nvarchar secret" }
    if ($Name -like "*Csv") { return "nvarchar CSV" }
    if ($Name -eq "MaxBatchesPerRun") { return "int nullable" }
    if ($Name -match 'Seconds|Count|Size$' -or $Name -eq "SyncId") { return "int" }
    if ($Name -match '^(Is|Auto|Create|Validate)' -or $Name -in @("InsertOnly","FullScanAllow")) { return "bit" }
    return "nvarchar"
}

function Get-AllowedValues {
    param([string]$Name)
    if ($overrides.ContainsKey($Name)) { return $overrides[$Name].Allowed }
    if ($Name -like "*AuthMode") { return '`Integrated` for Windows auth; anything else resolves to SQL auth.' }
    if ($Name -like "*Csv") { return "Comma-separated values." }
    if ((Get-TypeName $Name) -eq "bit") { return '`0` or `1`.' }
    if ((Get-TypeName $Name) -eq "int") { return 'Positive integer unless the operating model explicitly allows `0`.' }
    return "Project-specific string value."
}

function Get-DefaultValueText {
    param([string]$Name)
    if ($overrides.ContainsKey($Name)) { return $overrides[$Name].Default }
    if ($Name -in @("ColumnsCsv","ExcludeColumnsCsv","SourceWhereClause","PreSyncSql","PostSyncSql")) { return "Blank means not active." }
    if ($Name -eq "MaxBatchesPerRun") { return '`NULL` means unlimited incremental batches.' }
    if ($Name -in @("InsertOnly")) { return "Runtime helper default is false." }
    return "No database default confirmed; store explicitly."
}

function Get-EffectText {
    param([string]$Name)
    if ($overrides.ContainsKey($Name)) { return $overrides[$Name].Effect }
    if ($Name -like "Source*") { return "Changes how the runtime connects to or reads from the source side." }
    if ($Name -like "Destination*") { return "Changes how the runtime connects to or writes to the destination side." }
    if ($Name -like "*Csv") { return "Changes the final sync column or key selection." }
    if ($Name -like "*Sql") { return "Runs arbitrary SQL on the destination connection." }
    if ($Name -eq "BatchSize") { return "Changes batch and bulk-copy size." }
    if ($Name -eq "CommandTimeoutSeconds") { return "Changes SQL and bulk-copy timeout behaviour." }
    if ($Name -eq "FullScanAllow") { return "Controls whether incremental mode can start without existing checkpoint state." }
    if ($Name -eq "InsertOnly") { return "Skips updates and inserts only missing keys during incremental sync." }
    if ($Name -eq "MaxBatchesPerRun") { return "Stops incremental processing after the configured number of batches." }
    if ($Name -eq "AutoCreateDestinationTable") { return "Allows the runtime to create a missing destination table from source metadata." }
    if ($Name -eq "CreatePrimaryKeyOnAutoCreate") { return "Adds a PK on auto-created tables using configured key columns." }
    if ($Name -eq "ValidateDestinationSchema") { return "Enables required-column validation before sync work." }
    if ($Name -eq "IsEnabled") { return "Short-circuits the sync before work starts when disabled." }
    return "Changes runtime behaviour for this sync definition."
}

function Get-DependenciesText {
    param([string]$Name)
    if ($overrides.ContainsKey($Name) -and $overrides[$Name].ContainsKey("Dependencies")) { return $overrides[$Name].Dependencies }
    return 'Review interactions with `SyncMode`, column selection, and `Sync.TableState` checkpoints before changing this field.'
}

function Get-ExampleValuesText {
    param([string]$Name)
    if ($overrides.ContainsKey($Name) -and $overrides[$Name].ContainsKey("Examples")) { return $overrides[$Name].Examples }
    return '`example-value`'
}

function Get-ScenarioText {
    param([string]$Name)
    if ($overrides.ContainsKey($Name) -and $overrides[$Name].ContainsKey("Scenario")) { return $overrides[$Name].Scenario }
    return 'Validate the next run using `Sync.RunLog` and `Sync.RunActionLog` after changing this field.'
}

function Get-TroubleshootingText {
    param([string]$Name)
    if ($overrides.ContainsKey($Name) -and $overrides[$Name].ContainsKey("Troubleshooting")) { return $overrides[$Name].Troubleshooting }
    return "Trace the active config row, then compare runtime log output with the stored value."
}

function Get-Risk {
    param([string]$Name)
    if ($overrides.ContainsKey($Name)) { return $overrides[$Name].Risk }
    if ($Name -like "Source*" -or $Name -like "Destination*" -or $Name -in @("BatchSize","InsertOnly","FullScanAllow","AutoCreateDestinationTable")) { return "high" }
    return "medium"
}

function Get-CodeRefs {
    param(
        [string]$Name,
        [string[]]$Lines
    )

    $refs = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        $directPattern = '\bcfg\.' + [regex]::Escape($Name) + '\b'
        $indirectPattern = 'ColumnName "' + [regex]::Escape($Name) + '"'
        if ($line -match $directPattern -or $line -match $indirectPattern) {
            $refs.Add('`Sync-ConfiguredSqlTable.ps1:{0}`' -f ($i + 1))
        }
    }

    if ($refs.Count -eq 0) { return "No direct references detected." }
    return ($refs | Select-Object -Unique) -join ", "
}

New-Item -ItemType Directory -Force -Path $generatedConfigRoot | Out-Null
New-Item -ItemType Directory -Force -Path $flagsRoot | Out-Null

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Could not locate Sync-ConfiguredSqlTable.ps1 at [$scriptPath]."
}

$lines = Get-Content -Path $scriptPath

$rows = foreach ($item in $confirmedItems) {
    [pscustomobject]@{
        Name = $item
        TypeName = Get-TypeName $item
        Allowed = Get-AllowedValues $item
        DefaultValue = Get-DefaultValueText $item
        NullBehaviour = "Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts."
        CodeRefs = Get-CodeRefs -Name $item -Lines $lines
        Effect = Get-EffectText $item
        SideEffects = "Read once at process start. Mid-run edits do not reconfigure the already-running process."
        Dependencies = Get-DependenciesText $item
        Scope = 'Usually per sync row in `Sync.TableConfig`; connection fields are also environment-specific.'
        LiveChange = 'Safe for future runs only. Do not edit `Sync.TableState` during an active run.'
        Refresh = "No cache refresh exists in the script. Start a new process to pick up the change."
        Examples = Get-ExampleValuesText $item
        Scenario = Get-ScenarioText $item
        Troubleshooting = Get-TroubleshootingText $item
        Risk = Get-Risk $item
        Confidence = "confirmed"
    }
}

$referenceLines = New-Object System.Collections.Generic.List[string]
$referenceLines.Add("# Configuration Reference")
$referenceLines.Add("")
$referenceLines.Add('This page is generated from `Sync-ConfiguredSqlTable.ps1` usage patterns by `sql-cockpit-docs/scripts/generate_config_docs.ps1`.')
$referenceLines.Add("")
$referenceLines.Add("| Name | Type | Default | Risk | Confidence | Code refs |")
$referenceLines.Add("| --- | --- | --- | --- | --- | --- |")
foreach ($row in $rows) {
    $referenceLines.Add("| ``$($row.Name)`` | $($row.TypeName) | $($row.DefaultValue) | $($row.Risk) | $($row.Confidence) | $($row.CodeRefs) |")
}
$referenceLines.Add("")
$referenceLines.Add("## Notes")
$referenceLines.Add("")
$referenceLines.Add('- `Get-ConfigRow` loads `c.*` from `Sync.TableConfig`, so the table may contain extra columns that are currently unused.')
$referenceLines.Add('- `Sync.TableConfig` is read once at process start.')
$referenceLines.Add('- `Sync.TableState` is updated during the run and acts as the checkpoint source for the next run.')
$referenceLines.Add('- The highest-risk settings are `SyncMode`, key and watermark settings, connection targets, `SourceWhereClause`, and pre/post SQL hooks.')
$referenceLines.Add("")
Set-Content -Path (Join-Path $generatedConfigRoot "reference.md") -Value $referenceLines -Encoding UTF8

$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add("# Flag Pages")
$indexLines.Add("")
$indexLines.Add("Generated detail pages for confirmed runtime fields.")
$indexLines.Add("")

foreach ($row in $rows) {
    $slug = Get-Slug $row.Name
    $indexLines.Add("- [$($row.Name)]($slug.md)")

    $pageLines = @(
        "# $($row.Name)",
        "",
        '- Table: `Sync.TableConfig`',
        "- Column: ``$($row.Name)``",
        "- Data type: $($row.TypeName)",
        "- Allowed values: $($row.Allowed)",
        "- Default or observed default: $($row.DefaultValue)",
        "- Null behaviour: $($row.NullBehaviour)",
        "- Where it is read in code: $($row.CodeRefs)",
        "- Functional effect: $($row.Effect)",
        "- Side effects: $($row.SideEffects)",
        "- Dependencies and conflicts: $($row.Dependencies)",
        "- Scope: $($row.Scope)",
        "- Safe to change live: $($row.LiveChange)",
        "- Refresh or restart requirement: $($row.Refresh)",
        "- Example values: $($row.Examples)",
        "- Example scenario: $($row.Scenario)",
        "- Troubleshooting: $($row.Troubleshooting)",
        "- Risk rating: $($row.Risk)",
        "- Confidence: $($row.Confidence)",
        ""
    )

    Set-Content -Path (Join-Path $flagsRoot "$slug.md") -Value $pageLines -Encoding UTF8
}

Set-Content -Path (Join-Path $flagsRoot "index.md") -Value $indexLines -Encoding UTF8
