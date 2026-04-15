# Analyze Tables And Batch Sizing

Use these scripts when you want to answer two operational questions:

- Which sync rows target a given server or table name?
- What `BatchSize` range is reasonable for a specific source table?

These scripts are read-only. They inspect `Sync.TableConfig` and live SQL metadata, but they do not update control tables or change runtime state.

If you want the trade-offs explained in operator terms, read [Batch Size Caveats](batch-size-caveats.md) alongside this page.

## Why `BatchSize` needs analysis

`BatchSize` is not driven by row count alone.

In the current engine, the same value affects:

- `SELECT TOP (BatchSize)` when reading each source batch
- `SqlBulkCopy.BatchSize` when writing the stage table

That means the safe range depends on:

- average row width
- whether the table contains `varchar(max)`, `nvarchar(max)`, `varbinary(max)`, `xml`, `text`, `ntext`, or `image`
- network and source-query latency
- destination log and tempdb throughput
- whether the run is incremental or full refresh

The recommendation scripts therefore provide advisory ranges, not guaranteed-optimal values.

For a visual explainer of why small, balanced, and large batches behave differently, see [Batch Size Caveats](batch-size-caveats.md).

## Script 1: find matching sync rows

Use `Find-TableSyncConfig.ps1` to search `Sync.TableConfig` by source or destination endpoint.

Example: find sync rows by source server and table name

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Find-TableSyncConfig.ps1 `
  -ConfigServer "NASCAR" `
  -ConfigDatabase "EPC_Imports_PCK" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate `
  -MatchOn Source `
  -ServerPattern "APTOS*" `
  -TablePattern "hierarchy_group"
```

Example: include a source-table `BatchSize` recommendation for each matched row

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Find-TableSyncConfig.ps1 `
  -ConfigServer "NASCAR" `
  -ConfigDatabase "EPC_Imports_PCK" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate `
  -MatchOn Source `
  -TablePattern "hierarchy_group" `
  -IncludeBatchRecommendation
```

What it returns:

- matching `SyncId` and `SyncName`
- source and destination endpoints
- current `BatchSize`
- latest status summary from `Sync.TableState`
- optional advisory `BatchSize` range based on the live source table

## Script 2: profile one live table directly

Use `Get-TableBatchSizeRecommendation.ps1` when you already know the SQL table you want to inspect.

Example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Get-TableBatchSizeRecommendation.ps1 `
  -Server "APTOSSQL01" `
  -Database "Remote_Reporting_PEA" `
  -Schema "dbo" `
  -Table "hierarchy_group" `
  -IntegratedSecurity `
  -TrustServerCertificate
```

What it inspects:

- row count from SQL Server DMVs
- base-table and total storage footprint
- primary key presence
- non-clustered index count
- average row width
- presence of large-value columns

What it recommends:

- a balanced `Recommended BatchSize`
- a conservative lower bound
- an aggressive upper bound
- confidence level and caveats

## Safe change procedure

1. Locate the target sync row with `Find-TableSyncConfig.ps1`.
2. Profile the source table with `Get-TableBatchSizeRecommendation.ps1` or use `-IncludeBatchRecommendation`.
3. If rows are wide or LOB columns exist, start near the conservative end of the suggested range.
4. Change only `BatchSize` for that sync row.
5. Run one controlled execution.
6. Review `Sync.RunLog`, `Sync.RunActionLog`, duration, row counts, and memory/log pressure before increasing further.

## Reading the recommendation

- `within-range`: current `BatchSize` already sits between conservative and aggressive guidance.
- `below-range`: current `BatchSize` is smaller than the conservative guidance. This may be fine if you are protecting a fragile source or destination.
- `above-range`: current `BatchSize` is larger than the aggressive guidance. Review memory usage, long-running batch windows, and log growth risk before keeping it there.

## Confidence and limitations

Confirmed:

- `BatchSize` is used by both the source paging query and `SqlBulkCopy.BatchSize`.
- the new scripts inspect live SQL metadata and control-table rows without writing changes

Inferred:

- the recommendation model uses average row width and LOB detection as a proxy for memory and throughput pressure
- the balanced value is a safe starting point, not an exact optimum for every environment

Operational risk:

- low runtime risk from the scripts themselves because they are read-only
- medium change risk if operators treat the recommendation as absolute and skip a controlled validation run
