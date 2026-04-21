# Object Search API

SQL Cockpit now exposes a local object-search API through the existing Node host.

`Start-SqlTablesSyncWorkspace.ps1` now starts the Lucene.NET sidecar automatically alongside the docs host, notifications service, and Node API. The sidecar listen URL comes from local object-search settings, and the safe default remains loopback-only at `http://127.0.0.1:8094/`.

`Start-SqlObjectSearchService.ps1` now prefers a bundled self-contained executable from `service.executablePath` in the settings file, and only falls back to `dotnet run` when no bundled executable is present.

## Deployment model: code-only plus local cache

- tracked template: `sql-cockpit-object-search/sql-object-search.settings.template.json`
- tracked default: `sql-cockpit-object-search/sql-object-search.settings.json` (safe defaults only)
- local override (ignored): `sql-cockpit-object-search/sql-object-search.settings.local.json`
- cache and sync artifacts (ignored): `sql-cockpit-object-search/data/object-search/*` and `sql-cockpit-object-search/Logs/ObjectSearch/*`

Runtime resolution order for settings when no explicit path is supplied:

1. `sql-object-search.settings.local.json`
2. `sql-object-search.settings.json`
3. `sql-object-search.settings.template.json`

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/object-search/health` | Check whether the Lucene.NET sidecar is reachable. |
| `GET` | `/api/object-search/status` | Return index status plus the latest PowerShell sync status file. |
| `GET` | `/api/object-search/sync-log?limit=80&operationId=...` | Return recent lines from the PowerShell object-search sync log, optionally scoped to one sync operation. |
| `GET` | `/api/object-search/search?q=...` | Search database objects with optional `database`, `schema`, `objectType`, and `limit` filters. |
| `GET` | `/api/object-search/recent?limit=8` | Return the most recently modified indexed objects from Lucene.NET for command-palette suggestions. |
| `GET` | `/api/object-search/objects/{id}` | Return one indexed object document and its stored detail fields. |
| `POST` | `/api/object-search/index/refresh` | Run the PowerShell incremental sync pipeline. |
| `POST` | `/api/object-search/index/rebuild` | Run the PowerShell full rebuild pipeline. |
| `POST` | `/api/object-search/index/sync-connection` | Validate one Connection Manager saved profile payload and run an incremental schema sync for that connection. |

## Request and response notes

- supported `objectType` filters:
  `Table`, `View`, `Procedure`, `Function`, `Trigger`, `Column`, `Index`, `Constraint`, and `Synonym`
  omit `objectType` or pass an empty value to search all indexed object types
- search response fields:
  `id`, `objectName`, `qualifiedName`, `objectType`, `schemaName`, `databaseName`, `score`, `previewSnippet`, `modifiedDate`, `sourceServer`, `parentQualifiedName`
- recent response fields:
  `totalHits` plus `items`; each item includes `id`, `objectName`, `qualifiedName`, `objectType`, `objectTypeDescription`, `schemaName`, `databaseName`, `modifiedDate`, `sourceServer`, `parentQualifiedName`, and `sourceName`
  the sidecar sorts by stored `modifiedDate` from the current Lucene index, so the list reflects indexed metadata and does not depend on browser local storage
- detail response fields:
  canonical indexed document fields including `definition`, `columns`, `parameters`, `referencedObjects`, and `tags`
- rebuild and refresh requests:
  optional JSON body with `sourceServer` and `databaseName` to scope one configured source
  optional `connection` object for an explicit local saved profile, with `profileName`, `server`, `database`, `authMode`, `username`, `password`, `integratedSecurity`, and `trustServerCertificate`
  `Sync-SqlObjectSearchIndex.ps1` writes progress to `sync.log` and reserves stdout for the final JSON payload consumed by Node
- progress tracking:
  `GET /api/object-search/status` includes sync fields such as `operationId`, `isRunning`, `phase`, `message`, `currentSource`, `currentSourceIndex`, `totalSources`, `progressPercent`, `sourceProgressPercent`, and `lastHeartbeatUtc`
  `GET /api/object-search/sync-log?limit=80&operationId=...` returns the tail of matching operation lines from `Logs/ObjectSearch/sync.log` for operator visibility during long-running server-wide indexing
- granular sync stages:
  the PowerShell sync updates status and logs around connecting, base object extraction, column extraction, parameter extraction, dependency extraction, index extraction, constraint extraction, document building, manifest reads, scope replacement, upload batches, stale-delete batches, and manifest writes
  the document-building step is split into `building-document-lookups`, `building-object-documents`, `building-column-documents`, `building-index-documents`, and `building-constraint-documents`; large loops emit periodic count updates so long PowerShell normalization phases do not look hung
  `progressPercent` is the weighted server-wide percentage across databases, while `sourceProgressPercent` is the percentage for the current database only
- manifest reads:
  a log line such as `Reading current manifest ids for [server/database]` means the PowerShell sync is asking SQL Server for the full set of document ids that should currently exist for that database; this is used by incremental syncs to detect deleted objects
  full syncs skip that extra SQL manifest read and use the ids from the just-built full document set as the current manifest, which avoids re-scanning the same database immediately after document construction
  full-sync manifest-id collection emits periodic `Collected n of m built document ids` messages before Lucene scope replacement begins
  incremental manifest reads are split into `manifest-objects`, `manifest-columns`, `manifest-indexes`, and `manifest-constraints` phases so the progress modal shows which catalog category is taking time
  the current manifest ids are compared with the previous manifest file under `sync.manifestDirectory` so the sync can remove stale Lucene documents for SQL objects that were dropped or renamed since the last run
  this is especially important for child objects such as columns, indexes, constraints, and parameters, because SQL Server catalog views do not provide a universal tombstone stream for deleted metadata
- post-build indexing:
  after document building, full syncs upload/upsert the new documents before deleting stale ids from the previous manifest, so a failed first upload does not leave that database scope empty in Lucene.NET
  built documents are written to a durable spool under `sync.spoolDirectory`; the checkpoint records `uploadedThrough` and `deletedThrough` so a later rerun can resume upload/delete work without rebuilding metadata from SQL Server
  PowerShell sends batch payloads to the sidecar as UTF-8 JSON bytes with `application/json; charset=utf-8`, which preserves SQL definitions containing non-ASCII characters such as currency symbols
  upload batches split recursively on `400 Bad Request` and structured sidecar batch-upsert `500` responses so oversized, malformed, or Lucene-rejected batches can be narrowed to smaller ranges, and single-document failures log the document id, type, name, and parent before failing the run
  the Lucene.NET sidecar validates each batch document before indexing and returns a structured JSON error body with the failing batch index and object identity instead of an opaque ASP.NET 500
  stale deletes are sent in chunks after upload succeeds, and manifest file writes log start and completion
- dashboard progress modal:
  `Sync Server To Search` opens a centered progress modal, polls `/api/object-search/status` and `/api/object-search/sync-log` while the sync is running, disables the active sync button, and moves all sync progress/log detail out of the Connection Manager form
  the modal displays elapsed `Time taken`, separate cards for `Overall progress` across the server-wide sync, and `Current database` progress for the active database
  while a sync is running, dismissing the modal minimizes it into a floating progress control that also shows elapsed time; the completed status can be closed after the process finishes
  the dashboard generates an `operationId` for each sync request and asks the log endpoint for only that operation, so older runs in the shared log file do not appear in the active modal
  the streamed sync-log panel auto-scrolls to the newest line whenever fresh log lines arrive while the modal is open
- completion notifications:
  when a saved-profile sync completes or fails, the dashboard adds a local bell notification and sends a native browser notification if the browser supports notifications, permission is granted, and browser alerts are enabled
  the sync button click is used to request browser notification permission when the browser has not already made a decision
- command palette recent objects:
  when opened with an empty search, the palette loads `Recent Objects` from `GET /api/object-search/recent?limit=8`; opening an object does not write command-palette recent history to browser local storage
- saved-profile sync request:
  `POST /api/object-search/index/sync-connection` expects the same `connection` object, validates `server` plus SQL-auth `username`, and runs a full schema reindex for the selected saved profile before PowerShell returns
  Connection Manager sends a blank `connection.database` by design, so PowerShell connects to `master`, enumerates all accessible online user databases on that server instance, and indexes metadata for each one

## Object-search settings

- storage location:
  tracked safe settings at `sql-cockpit-object-search/sql-object-search.settings.template.json` and `sql-cockpit-object-search/sql-object-search.settings.json`; local operator override at `sql-cockpit-object-search/sql-object-search.settings.local.json` (ignored)
- valid values:
  `service.listenUrl` must be an absolute `http://` loopback URL, `service.executablePath` may be blank or point to a bundled `SqlObjectSearch.Service.exe`, `service.indexRoot` and `sync.*Path` values must resolve to writable local paths, `sync.batchSize` must be a positive integer, `sync.spoolDirectory` must be a writable local directory, and each source must define at least `server`, `database`, and an auth mode
- defaults:
  `service.listenUrl = http://127.0.0.1:8094/`, `service.executablePath = ./bin/win-x64/SqlObjectSearch.Service.exe`, `sync.batchSize = 200`, `sync.manifestDirectory = ./data/object-search/manifests`, `sync.spoolDirectory = ./data/object-search/spool`, `sync.statusPath = ./data/object-search/sync-status.json`, `sync.logPath = ./Logs/ObjectSearch/sync.log`, `service.maxResults = 40`, `service.snippetLength = 240`
- code paths affected:
  `Start-SqlObjectSearchService.ps1`, `Publish-SqlObjectSearchService.ps1`, `Start-SqlTablesSyncWorkspace.ps1`, `Sync-SqlObjectSearchIndex.ps1`, `sql-cockpit-object-search/SqlObjectSearch.Service/Program.cs`, `sql-cockpit-api/server.js`, `sql-cockpit-api/lib/object-search-service.js`, `sql-cockpit-api/components/dashboard-client.js`, and `sql-cockpit-api/components/object-search-palette.js`
- operational risk:
  medium, because indexed definitions can include sensitive SQL text and the local index mirrors object names, definitions, columns, and dependencies on disk; durable spool files temporarily store the same built document payloads until a source completes successfully; startup will also fail if the bundled executable path is stale and no dotnet fallback is available
- safe change procedure:
  keep the service on loopback, copy `sql-object-search.settings.local.json.example` to `sql-object-search.settings.local.json`, publish the sidecar with `.\Publish-SqlObjectSearchService.ps1`, start the workspace and confirm the object-search health check passes, run one full sync for first bootstrap, run incremental refresh for daily updates, validate `GET /api/object-search/status`, and only then add more databases or widen the indexed scope
- confidence:
  confirmed for the local file locations, endpoint contract, and loopback-only service design; uncertain for exact source-definition coverage on object types where SQL Server catalog views do not expose full text
