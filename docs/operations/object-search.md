# Database Object Search Operations

## Daily flow

1. Start SQL Cockpit through `Start-SqlTablesSyncWorkspace.ps1` or start the Lucene.NET sidecar manually with `Start-SqlObjectSearchService.ps1` and then start `Start-SqlTablesSyncRestApi.ps1`.
3. Run `POST /api/object-search/index/refresh` or `.\Sync-SqlObjectSearchIndex.ps1 -Mode Incremental`.
4. Open SQL Cockpit and press `Ctrl+K`.
5. With an empty search, confirm `Recent Objects` contains recently modified indexed objects from Lucene.NET.
6. Select an indexed object and use the detail dropdown action `Open in SQL Editor` to verify definition hand-off into the editor workflow.

If `dotnet` is installed outside `PATH`, pass the explicit executable path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlTablesSyncWorkspace.ps1 `
  -ConfigServer "YOURSERVER" `
  -ConfigDatabase "YOURCONFIGDB" `
  -ConfigIntegratedSecurity `
  -DotNetExecutable "C:\custom\dotnet\dotnet.exe"
```

If `dotnet` is not installed yet:

1. Download it from the official Microsoft page:
   `https://dotnet.microsoft.com/en-us/download/dotnet`
2. Install the `.NET 8 SDK` on the machine used to build or publish the bundled sidecar.
3. Run `dotnet --info` in a new PowerShell session to confirm the install succeeded.
4. Run `.\Publish-SqlObjectSearchService.ps1` to produce the bundled `SqlObjectSearch.Service.exe`.

Important note:

- the SDK is required on the build machine because `Publish-SqlObjectSearchService.ps1` runs `dotnet publish`
- end-user machines do not need a separate .NET install once you ship the bundled `SqlObjectSearch.Service.exe`

## Full rebuild

Use a full rebuild when:

- a source database was added or removed
- a manifest file was deleted or corrupted
- search results appear stale after large schema churn
- you changed schema include or exclude filters

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Sync-SqlObjectSearchIndex.ps1 -Mode Full
```

## Clear local index and start again

Use this when you intentionally want to discard the local Lucene.NET index, resumable spool checkpoints, and stale-document manifests.

Common reasons:

- a branch switch or sidecar build mismatch left old payloads in the durable spool
- `/documents/batch` keeps replaying a bad checkpoint payload
- the local Lucene index is suspected to be corrupt
- you want a completely fresh object-search baseline

Important:

- stop the workspace or the object-search sidecar first, otherwise Lucene.NET will keep `index\write.lock` open and Windows will block deletion
- deleting `spool` means the next sync cannot resume the current long-running operation and must rebuild metadata from SQL Server
- deleting `manifests` removes the previous baseline used for stale-document comparison

Stop the sidecar process on the default object-search port:

```powershell
Get-NetTCPConnection -LocalPort 8094 -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
        Write-Host "Stopping object-search service PID $_"
        Stop-Process -Id $_ -Force
    }
```

If deletion still reports `write.lock`, check for a stale `dotnet` or bundled sidecar process and stop only the one that belongs to this workspace:

```powershell
Get-Process dotnet, SqlObjectSearch.Service -ErrorAction SilentlyContinue
```

Clear the object-search state:

```powershell
$ErrorActionPreference = 'Stop'

$root = Resolve-Path 'C:\Scripts\SQL Tables Sync\object-search\data\object-search'

foreach ($name in @('index', 'spool', 'manifests')) {
    $path = Join-Path $root $name

    if (Test-Path -LiteralPath $path) {
        Write-Host "Removing $path"
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

New-Item -ItemType Directory -Force -Path `
    (Join-Path $root 'index'), `
    (Join-Path $root 'spool'), `
    (Join-Path $root 'manifests') | Out-Null

Write-Host 'Object-search index, spool, and manifests cleared.'
```

Restart the workspace, then run `Sync Schema To Search` or a full sync again.

## Case study: full sync for one database

This case study uses a real Object Search Sync modal log from a full sync of `firebird/RMSTEST`.

The run produced this high-level outcome:

| Metric | Value | Meaning |
| --- | ---: | --- |
| Base objects | 8,783 | Parent SQL Server objects such as tables, views, procedures, functions, triggers, and synonyms. |
| Columns | 86,592 | Column metadata read for tables and views. |
| Parameters | 5,185 | Procedure and function parameter metadata. |
| Dependency rows | 19,831 | Object-reference relationships used to enrich search and dependency discovery. |
| Indexes | 322 | Index metadata that can be searched directly and attached to parent table context. |
| Constraints | 7,328 | Constraint metadata such as primary keys, foreign keys, unique constraints, checks, and defaults where available. |
| Searchable documents | 103,025 | Final documents prepared for Lucene.NET. This is larger than the base object count because child metadata can become searchable entries too. |

Example log:

```text
[2026-04-09T09:52:54.9262197Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Started object-search sync in Full mode.
[2026-04-09T09:52:55.4517171Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Syncing [firebird/RMSTEST] in Full mode.
[2026-04-09T09:52:55.6426179Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Reading base objects from [firebird/RMSTEST].
[2026-04-09T09:52:56.3879908Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Read 8783 base objects from [firebird/RMSTEST].
[2026-04-09T09:52:56.3981532Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Reading columns from [firebird/RMSTEST].
[2026-04-09T09:52:58.7150229Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Read 86592 columns from [firebird/RMSTEST].
[2026-04-09T09:52:58.7277332Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Reading parameters from [firebird/RMSTEST].
[2026-04-09T09:52:59.3423113Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Read 5185 parameters from [firebird/RMSTEST].
[2026-04-09T09:52:59.3601190Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Reading referenced objects from [firebird/RMSTEST].
[2026-04-09T09:52:59.8313186Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Read 19831 dependency rows from [firebird/RMSTEST].
[2026-04-09T09:52:59.8775983Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Reading indexes from [firebird/RMSTEST].
[2026-04-09T09:52:59.9747634Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Read 322 indexes from [firebird/RMSTEST].
[2026-04-09T09:52:59.9823912Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Reading constraints from [firebird/RMSTEST].
[2026-04-09T09:53:00.3102853Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Read 7328 constraints from [firebird/RMSTEST].
[2026-04-09T09:53:00.3265604Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Building documents for [firebird/RMSTEST].
[2026-04-09T09:54:09.4853292Z] [1ed4d126-d352-42af-b212-d5d31253ffed] Built 103025 searchable documents for [firebird/RMSTEST].
```

How to read each step:

| Log stage | What it does | Outcome |
| --- | --- | --- |
| `Started object-search sync in Full mode` | Starts a new operation and assigns the operation id shown in square brackets. | The modal can scope status and streamed logs to this one run. |
| `Syncing [server/database] in Full mode` | Selects the current database and declares the effective mode. | In full mode, existing documents for that database scope are replaced before the new documents are uploaded. |
| `Reading base objects` | Reads parent SQL Server object metadata from catalog views such as `sys.objects`, `sys.schemas`, `sys.sql_modules`, `sys.tables`, `sys.views`, and `sys.synonyms`. | Produces the parent object list that anchors search results. |
| `Reading columns` | Reads column and type metadata for tables and views. | Produces searchable `Column` records and enriches table/view documents. |
| `Reading parameters` | Reads stored procedure and function parameter metadata. | Produces parameter text for procedure/function search and signatures. |
| `Reading referenced objects` | Reads dependency rows, such as one procedure referencing a table or view. | Adds dependency context to object documents. |
| `Reading indexes` | Reads index metadata for table-like objects. | Produces searchable `Index` records and enriches parent table context. |
| `Reading constraints` | Reads constraint metadata where SQL Server exposes it. | Produces searchable `Constraint` records and enriches parent table context. |
| `Building documents` | Converts raw catalog rows into the canonical object-search document model. | Creates stable document ids, qualified names, searchable text, tags, child-object documents, and metadata arrays for Lucene.NET. |
| `Building document lookup tables` | Groups columns, parameters, and dependency rows by parent object id before parent documents are created. | Parent object documents can include their column lists, parameter lists, and referenced objects without repeatedly scanning all rows. |
| `Building parent object documents` | Creates documents for tables, views, procedures, functions, triggers, and synonyms. | The command palette can find parent SQL objects by name, schema, definition, tags, and related metadata. |
| `Building column documents` | Creates one searchable document per column. Large databases emit periodic count updates during this loop. | The command palette can search columns independently from their parent tables/views. |
| `Building index documents` | Creates one searchable document per index. | The command palette can search index names and index definitions. |
| `Building constraint documents` | Creates one searchable document per constraint. Large databases emit periodic count updates during this loop. | The command palette can search primary keys, foreign keys, check/default constraints, and related table context. |
| `Built n searchable documents` | Finishes the in-memory document-building phase for this database. | The next phases can replace existing scope documents, upload batches to Lucene.NET, calculate stale deletes, and write the manifest. |
| `Collecting n built document ids` | Full syncs derive the fresh manifest from the just-built document set instead of re-querying SQL Server. Large document sets emit periodic count updates. | The manifest can be written for future incremental syncs, and the modal stays active while ids are collected. |
| `Uploading documents n-m of total` | Sends one batch of built documents to the Lucene.NET sidecar. Failed `400 Bad Request` batches are split into smaller batches to isolate oversized or malformed payloads. | The local Lucene index receives searchable metadata for the command palette without first emptying the old scope. |
| `Deleting stale documents n-m of total` | Removes ids that existed in the previous manifest but are not in the current manifest. This runs after upload succeeds. | Old dropped or renamed objects are removed without risking an empty index if the first upload fails. |
| `Writing manifest file` | Persists the current document id list under the object-search manifest directory. | Future incremental syncs can compare this manifest with the current catalog shape and delete stale results. |

Performance interpretation:

| Observation | Interpretation |
| --- | --- |
| Catalog reads finished in seconds. | SQL Server metadata extraction was not the bottleneck in this sample. |
| `Building documents` took about 69 seconds. | The expensive step was PowerShell-side normalization and document construction over large arrays. |
| Final document count was 103,025. | The command palette can search much more than parent objects; child metadata is searchable too. |

Robustness note:

- full syncs upsert new documents before stale deletes, so an upload failure should leave the previous searchable index content in place for that database
- after documents are built, the sync writes `documents.json` and `checkpoint.json` under `sync.spoolDirectory`; rerunning the same source/mode can reload that spool and continue from the saved `uploadedThrough` or `deletedThrough` offsets
- resumed `documents.json` files are expanded back into individual documents before upload batching; a resume log should show the original document count, not `Loaded 1 spooled documents`, for a large database
- completed source syncs remove their spool directory after the manifest file is written
- if a spool is no longer wanted, stop the sync and delete the matching source directory under `object-search/data/object-search/spool`; the next run will rebuild from SQL Server
- upload batches are adaptively split on `400 Bad Request`; if the failing unit is a single document, the sync log records the document id, object type, qualified name, and parent before the run fails
- a failed stale-delete or manifest-write step can still fail the run, but this happens after the fresh documents have been uploaded

## Manifest phase

During a sync you may see a log line like:

```text
Reading current manifest ids for [firebird/RMSTEST].
```

This is normal. At that point the sync is reading the current SQL Server catalog shape and building the list of search document ids that should exist for that database.

Optimization note:

- full syncs use the ids from the documents they just built as the current manifest, so they avoid a second full catalog scan after document construction
- incremental syncs still read current manifest ids from SQL Server because they need a full current object-id view to detect dropped or renamed objects that would not appear in a modify-date filtered extraction
- incremental manifest reads are split into object, column, index, and constraint phases; if a database appears to pause in this part of the modal, the streamed log should show which category is currently being read

The manifest list is used for stale-document cleanup:

- the previous manifest file records what was indexed on the last successful run
- the current manifest list records what exists in SQL Server now
- ids that existed previously but no longer exist now can be deleted from the Lucene.NET index
- this prevents the command palette from returning dropped or renamed objects

This matters most for child metadata such as columns, indexes, constraints, and parameters. SQL Server exposes modification dates for many parent objects, but it does not provide a single reliable tombstone stream for every deleted child object. Manifest comparison is the local, self-contained way the search index keeps itself tidy without requiring external infrastructure.

## Safe change procedure

1. Keep both the Node host and Lucene.NET service on loopback.
2. Validate `GET /api/object-search/health`.
3. Run one incremental refresh against a low-risk source.
4. Validate `GET /api/object-search/status`.
5. Search for one known object by exact name and one by definition text.
6. Check `GET /api/object-search/recent?limit=8` or reopen the command palette to confirm the recent-object list is coming from the refreshed index.
7. Only then expand the configured source list or run a full rebuild.

## Operational risks

- local disk now contains searchable object definitions and dependency metadata
- incremental sync uses parent-object `modify_date` as the practical change watermark for child records
- the command palette recent-object list is sorted from stored `modifiedDate`; objects without a parseable value appear after dated objects
- if the Lucene.NET sidecar is down, the command palette falls back to quick links only
- the Lucene.NET sidecar depends on a local `dotnet` runtime; if it is missing from `PATH`, the workspace health output will show the startup failure and all sync calls will fail until the runtime is installed

## Confidence

- confirmed:
  the refresh and rebuild flows are local-only and PowerShell-driven
- uncertain:
  some child-object delete detection still depends on manifest comparison rather than SQL-native tombstones, so rare catalog edge cases should be handled with a full rebuild
