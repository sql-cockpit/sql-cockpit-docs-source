# Troubleshooting

## Symptom: dashboard redirects to `/setup`

Checks:

- no local SQL Cockpit user may exist yet for this workstation
- `data/sql-cockpit/sql-cockpit-local.sqlite` may be missing or unreadable
- the Node host process must be able to create `data/sql-cockpit`

Safe procedure:

1. Confirm the workspace is running on loopback.
2. Open `/setup`.
3. Create the first local administrator.
4. If setup still loops, inspect `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl` for local SQLite or file-permission errors.

## Symptom: login fails even though the SQL config database is reachable

Checks:

- SQL Cockpit local login is separate from SQL Server login state
- the username must match the local SQL Cockpit account created during `/setup`
- repeated failures may have triggered the local lockout window
- `data/sql-cockpit/sql-cockpit-local.sqlite` must still be present and readable

Safe procedure:

1. Wait for the 15-minute lockout window if repeated failures occurred.
2. Sign in again with the local SQL Cockpit username, not the SQL Server login unless they are intentionally the same.
3. If the password is unknown and recovery is not possible, back up and reset `data/sql-cockpit/sql-cockpit-local.sqlite`, then run `/setup` again.

## Symptom: `PUT /api/preferences` returns `{"error":"FOREIGN KEY constraint failed"}`

Checks:

- confirm the error is coming from the local auth database, not the SQL Server config database
- inspect `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl` for the matching `eventId`
- confirm the authenticated request is resolving `session.user.id` to `users.id`, not `sessions.id`
- confirm `data/sql-cockpit/sql-cockpit-local.sqlite` still contains the expected `users` row for the signed-in account

Confirmed from code:

- `user_preferences.user_id` has a foreign key to `users.id`
- authenticated preference reads and writes must use the owning `users.id`
- `sessions.id` is a different key and cannot be inserted into `user_preferences.user_id`

Safe procedure:

1. Restart the web app so the current `webapp/lib/local-auth.js` code is loaded.
2. Sign in again to mint a fresh session after restart.
3. Retry `GET /api/preferences` and `PUT /api/preferences`.
4. If the error persists, inspect the newest matching `server-errors-YYYY-MM-DD.jsonl` line and verify the local SQLite `users`, `sessions`, and `user_preferences` rows together before deleting anything.

## Symptom: `No config row found`

Checks:

- The launcher passed the expected `-SyncName` or `-SyncId`.
- The config server, database, and schema point to the correct control database.
- The `SyncName` value exactly matches the row in `Sync.TableConfig`.

## Symptom: sync exits immediately without doing work

Checks:

- `IsEnabled` may be `0`.
- Another process may already hold the applock for `Sync:<SyncName>`.

## Symptom: login succeeds to server but not database

Checks:

- `SourceDatabase` or `DestinationDatabase` may be wrong.
- The login may exist on the SQL instance but not have rights to the target database.

The script contains a diagnostic retry against `master` specifically to help distinguish those cases.

## Symptom: incremental sync re-read too much data

Checks:

- `LastWatermarkValue` and `LastKeyValue`
- `FullScanAllow`
- `WatermarkColumn` and `WatermarkType`
- `KeyColumnsCsv`

## Symptom: rows are missing after a run

Checks:

- `SourceWhereClause`
- `ColumnsCsv` and `ExcludeColumnsCsv`
- whether `InsertOnly=1` prevented updates to existing rows
- whether the destination was empty and the run switched to full refresh

## Symptom: full refresh is unexpectedly replacing the whole table

Checks:

- `SyncMode`
- whether the destination row count was zero at startup
- recent `RunActionLog` entries for `SyncModeOverride`

## Symptom: destination table was created unexpectedly

Checks:

- `AutoCreateDestinationTable`
- `DestinationSchema`
- `DestinationTable`

## Symptom: run fails after data movement appears to finish

Checks:

- `PostSyncSql`
- final destination count validation
- permissions for `TRUNCATE`, `DELETE`, or `IDENTITY_INSERT`

## Symptom: run fails before reading any source rows

Checks:

- source/destination connection fields
- auth mode fields
- `ValidateDestinationSchema`
- `PreSyncSql`

## Symptom: one batch runs for a long time or memory spikes during sync

Checks:

- `BatchSize`
- whether the source table has wide rows or large-value columns
- whether the source query is returning more columns than expected
- destination log growth or tempdb pressure during the same window

Use [Analyze Tables And Batch Sizing](analyze-table-batch-sizing.md) to profile the source table, then lower `BatchSize` and re-run one controlled test if the current value is above the advisory range.

## Symptom: REST API returns SQL login or schema errors

Checks:

- the API process is pointed at the intended config database
- `ConfigIntegratedSecurity` versus SQL-auth parameters
- the target source and destination tables still exist
- the account used by the API can read SQL catalog views in both databases

Safe procedure:

1. Run `.\Test-RestApiEndpoint.ps1` for the failing operation with the same payload you sent to the API.
2. Pass the real `ConfigServer`, `ConfigDatabase`, `ConfigSchema`, and auth mode used by `Start-SqlTablesSyncRestApi.ps1`.
3. Compare the `Rest` and `Direct` sections first:
   `StatusCode`, `Body.error`, and `Comparison.BodyHashesMatch`.
4. If the REST side includes an `eventId`, inspect the newest matching line in `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl`.
5. If the direct PowerShell side fails too, focus on `Invoke-SqlTablesSyncRestOperation.ps1` or the shared module instead of the HTTP route.

Confirmed from code:

- `Test-RestApiEndpoint.ps1` can hit the REST route and the equivalent direct PowerShell operation in one run
- the script can write one local JSON trace file under `.\Logs\RestApiTrace`
- the script can include the tail of the newest `server-errors-YYYY-MM-DD.jsonl` file to keep the HTTP trace and PowerShell comparison in one support artifact

## Symptom: REST API or dashboard will not start after the Node migration

Checks:

- `node --version` succeeds on the host machine
- `webapp/node_modules` exists because `npm install` has been run in `webapp`
- `Start-SqlTablesSyncRestApi.ps1 -NodeExecutable ...` points at the intended Node runtime
- `webapp/server.js` can read `Invoke-SqlTablesSyncRestOperation.ps1`
- no other process is already bound to the `ListenPrefix` port
- Windows has not reserved the target TCP port through an excluded port range
- if you started through `Start-SqlTablesSyncWorkspace.ps1`, read the workspace console summary first because it now waits for readiness and prints the tail of the child stdout or stderr log when the API or docs process exits early

Confirmed from code:

- `Start-SqlTablesSyncWorkspace.ps1` polls the docs endpoint, API health endpoint, and dashboard root until they respond or the child process exits
- early child-process exit details come from the per-process log files under `.\Logs`
- if the default workspace port is unavailable, the launcher tries the next available loopback ports automatically before it starts the child process
- if an operator explicitly supplied the listen prefix, the launcher fails fast instead of changing the requested port behind their back

Safe procedure:

1. Run `Start-SqlTablesSyncWorkspace.ps1` on loopback.
2. Wait for the readiness checks to finish before opening the browser.
3. If the launcher reports that it moved from `8080` or `8000`, use the printed replacement URL rather than the historical default.
4. If a check fails, inspect the stderr path printed by the launcher and compare it with the inline log tail shown in the console.
5. Resolve the missing Node runtime, missing `node_modules`, bad port binding, excluded-port reservation, or SQL/bootstrap error before retrying.

## Symptom: object-search schema sync fails while uploading to `/documents/batch`

This means the PowerShell extractor reached the local Lucene.NET sidecar, but the sidecar rejected or failed while indexing one upload batch.

Checks:

- confirm the object-search service is healthy with `GET http://127.0.0.1:8094/health`
- inspect the active modal log for `Uploading documents n-m` to identify the failed batch range
- inspect `.\Logs\object-search-service-*.stdout.log` for the sidecar exception if the API response body is not enough
- if a single document returns `400 Bad Request` and the SQL definition contains non-ASCII text such as currency symbols, accented characters, or smart punctuation, confirm the uploader is sending JSON as UTF-8 bytes with `application/json; charset=utf-8`
- if the modal says `Loaded 1 spooled documents` for a database that previously wrote thousands of documents, the resume reader has treated the whole JSON array as one payload; update `Sync-SqlObjectSearchIndex.ps1` and rerun so `documents.json` is enumerated item-by-item
- if the sidecar log shows `413` or an extremely large `/documents/batch` content length during resume, the same nested-spool symptom is likely
- if the error says `blank id` or `Failed to upsert document at batch index`, capture the reported `id`, `type`, `qualifiedName`, `parent`, and source database
- if the response shows every field as `<null>`, restart or republish the Lucene.NET sidecar so it uses the current JSON binding code; this usually means the running executable is stale or strict JSON casing prevented PowerShell's `id` payload from binding to the C# `Id` field
- confirm `object-search\data\object-search\spool\<server-database>\documents.json` and `checkpoint.json` still exist for the failed source

Confirmed from code:

- `Sync-SqlObjectSearchIndex.ps1` writes built documents to `sync.spoolDirectory` before upload, then records completed upload and delete offsets in `checkpoint.json`
- rerunning the same source and mode resumes from the durable spool when the checkpoint still matches the same server, database, and mode
- resumed spool documents are enumerated from `documents.json` as individual documents before batching, so large resume runs should continue in normal `sync.batchSize` chunks instead of one huge request
- the PowerShell uploader refuses to send documents with blank ids and logs the first invalid object identity
- the PowerShell uploader sends batch JSON as explicit UTF-8 bytes, which avoids ASP.NET rejecting valid SQL definitions that contain non-ASCII characters before the sidecar endpoint runs
- the uploader recursively splits `400 Bad Request` and structured sidecar batch-upsert `500` failures to narrow payload/indexing problems down to smaller ranges
- `object-search/SqlObjectSearch.Service/Program.cs` validates each document id before Lucene receives it and returns a JSON error body for `/documents/batch` failures
- the sidecar accepts JSON input with case-insensitive property matching so PowerShell payload names such as `id` and `objectType` bind to the C# record fields `Id` and `ObjectType`

Safe procedure:

1. Leave the spool directory in place.
2. Fix or restart the local object-search service if the health endpoint fails.
3. If the response identifies one malformed document, inspect the matching item in `documents.json` before deleting or editing any spool files.
4. Rerun the same sync request; do not switch between Full and Incremental if you want to reuse the existing checkpoint.
5. Only delete the affected spool directory when you intentionally want to rebuild metadata from SQL Server from scratch.

Risk notes:

- storage location: transient spool and checkpoint files under `object-search/sql-object-search.settings.json` setting `sync.spoolDirectory`
- valid values: local writable directory path
- default: `./data/object-search/spool`
- code paths affected: `Sync-SqlObjectSearchIndex.ps1` upload/resume logic and `object-search/SqlObjectSearch.Service/Program.cs` batch indexing
- operational risk: low to medium; the change improves diagnostics and resumability, but spool files contain SQL metadata and definitions until the source completes successfully
- confidence: confirmed for current batch validation and resume behavior; inferred that most repeat failures after this point are malformed payloads, invalid indexed fields, or local Lucene/index write errors

## Symptom: clearing object-search index fails on `write.lock`

Example error:

```text
Remove-Item : Cannot remove item ...\object-search\data\object-search\index\write.lock:
The process cannot access the file 'write.lock' because it is being used by another process.
```

This means the Lucene.NET sidecar still has the local index open. The `write.lock` file is expected while the sidecar is running; do not delete the index directory until the sidecar has stopped.

Checks:

- confirm whether port `8094` is still owned by the object-search sidecar
- confirm whether a `dotnet` or `SqlObjectSearch.Service` process is still running from this repository
- stop the sidecar before deleting `index`, `spool`, or `manifests`
- keep or back up the spool directory if you intend to resume a failed long-running sync rather than start from scratch

Safe procedure:

1. Stop the process listening on the object-search port:

```powershell
Get-NetTCPConnection -LocalPort 8094 -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
        Write-Host "Stopping object-search service PID $_"
        Stop-Process -Id $_ -Force
    }
```

2. If nothing is listening on the port but deletion still fails, inspect likely sidecar processes:

```powershell
Get-Process dotnet, SqlObjectSearch.Service -ErrorAction SilentlyContinue
```

3. Stop only the process that belongs to this workspace.

4. Clear the object-search state:

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

5. Restart the workspace and run `Sync Schema To Search` again.

Risk notes:

- storage location: `object-search\data\object-search\index`, `object-search\data\object-search\spool`, and `object-search\data\object-search\manifests`
- valid values: local directories owned by SQL Cockpit object search
- default: derived from `object-search/sql-object-search.settings.json`
- code paths affected: Lucene.NET index reads/writes, PowerShell resume checkpoints, and stale-document manifest comparison
- operational risk: medium; deleting `index` removes searchable results until the next successful sync, deleting `spool` removes resumability for the current failed run, and deleting `manifests` makes the next run behave like a fresh baseline for stale-object cleanup
- confidence: confirmed that Lucene.NET holds `write.lock` while the sidecar is active; inferred that any remaining lock after stopping port `8094` is usually another stale sidecar process from a previous branch or workspace run

## Symptom: `POST /api/servers/discover` returns HTTP 500

This usually means the SQL Server network enumerator returned an `IsClustered` field in a non-standard boolean format that the PowerShell discovery parser could not coerce.

Checks:

1. Inspect the returned JSON body for an `eventId`.
2. Open the newest `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl` entry with the same `eventId`.
3. Confirm whether the logged error mentions `Get-StsDiscoveredSqlServers` and `String was not recognized as a valid Boolean`.
4. If it does, update to the build that normalizes discovery values such as `Yes`, `No`, `1`, and `0` before retrying the discovery scan.

Notes:

- storage location for the affected value: transient `System.Data.Sql.SqlDataSourceEnumerator` discovery rows only; no `Sync.TableConfig` or `Sync.TableState` columns are involved
- valid values now accepted by the parser: native booleans plus common string and numeric forms such as `true`, `false`, `yes`, `no`, `1`, and `0`
- default: blank or missing `IsClustered` values remain `null` in the API response
- code paths affected: `SqlTablesSync.Tools.psm1`, `Invoke-SqlTablesSyncRestOperation.ps1`, and `webapp/server.js`
- operational risk: low for runtime safety because the fix only broadens read-only parsing of discovery metadata; low to medium for operator interpretation because SQL Browser discovery is still incomplete on filtered or locked-down networks
- safe change procedure: redeploy the updated module, rerun the discovery scan on a trusted network, and spot-check one discovered host with `Test Connection` before relying on the list
- confidence:
  - confirmed: the failing exception path and the normalization logic in `Get-StsDiscoveredSqlServers`
  - uncertain: the full set of string formats some third-party SQL Browser implementations may emit beyond the normalized values above

## Symptom: browser error is visible in SQL Cockpit but hard to trace afterward

Checks:

- `.\Logs\WebApp\client-errors-YYYY-MM-DD.jsonl` exists and has a new line for the failure window
- the browser action was reproduced once after this logging change landed
- the latest JSON line includes `context.source`, `page`, and `error.message`
- if the UI displayed an API `eventId`, compare it with `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl`

Confirmed from code:

- browser-side unhandled errors and unhandled promise rejections are posted to `POST /api/client-errors`
- route render failures caught by Next.js `webapp/app/error.js` are logged locally before the fallback UI is shown
- handled dashboard errors, such as failed bootstrap or action requests that stay inside the page shell, are also reported to the same local log stream
- API responses that come back with HTTP 500 now include an `eventId` whether the failure originated in the Node host or in a PowerShell operation envelope returned by `Invoke-SqlTablesSyncRestOperation.ps1`
- duplicate browser errors are suppressed only briefly, so repeated operator clicks can still produce multiple records over time

Safe procedure:

1. Reproduce the problem once.
2. Open the newest line in `.\Logs\WebApp\client-errors-YYYY-MM-DD.jsonl`.
3. If the browser showed an API `eventId`, search for the same id in `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl`.
4. Redact credentials, connection strings, and business-sensitive identifiers before sharing the trace outside the trusted support context.
5. Keep the web listener on loopback while collecting the logs, because the payload can include stack traces and request metadata.

Confirmed compatibility note:

- the Server Explorer metadata query now aliases the featured-object table row count as `[RowCount]`, which avoids the SQL Server reserved-keyword parse failure that previously returned `Incorrect syntax near the keyword 'RowCount'.`

## Symptom: MCP client connects but tool calls fail

Checks:

- the client is launching `Start-SqlTablesSyncMcpServer.ps1` with the expected config DB parameters
- the client supports MCP stdio framing and `tools/list` plus `tools/call`
- the requested `syncId` or `syncName` still exists in `Sync.TableConfig`
- the source and destination SQL credentials stored in the config row are still valid

## Symptom: object search shows quick links only or returns no database results

Checks:

- `Start-SqlTablesSyncWorkspace.ps1` or `Start-SqlObjectSearchService.ps1` is running
- `dotnet --info` succeeds on the host machine so the Lucene.NET sidecar can start
- `GET /api/object-search/health` succeeds
- `GET /api/object-search/status` shows a successful sync
- `object-search/sql-object-search.settings.json` contains the intended sources
- `.\Sync-SqlObjectSearchIndex.ps1 -Mode Incremental` completes successfully
- if a previous object-search sync crashed after document build, check `object-search/data/object-search/spool` for a durable checkpoint; rerunning the same source and mode should resume upload/delete work from that checkpoint
- older or partially-written checkpoint files are tolerated by the sync script; missing checkpoint fields are added on the next save rather than requiring manual JSON edits
- if the sync was launched from a saved Connection Manager profile, that profile includes a valid server name; a blank database means "enumerate all accessible online user databases on this server"

Safe procedure:

1. Validate the Lucene.NET sidecar health endpoint first.
2. Run one incremental refresh.
3. Inspect `data/object-search/sync-status.json`.
4. Inspect `Logs/ObjectSearch/sync.log`.
5. Inspect `object-search/data/object-search/spool` if the previous run failed after `Wrote durable spool`; keep the spool to resume, or delete the matching source folder to force a fresh rebuild from SQL Server.
6. If the sidecar health endpoint never comes up, inspect the object-search stderr log from the workspace output and resolve the missing .NET runtime or other startup error before retrying sync.
7. If `dotnet` is missing on the build machine, download it from the official Microsoft page:
   `https://dotnet.microsoft.com/en-us/download/dotnet`
8. Install the `.NET 8 SDK`, reopen PowerShell, and rerun `dotnet --info` before publishing the bundled sidecar again.
9. If results are still stale after heavy schema churn, run a full rebuild.
