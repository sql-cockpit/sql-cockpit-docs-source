# Configuration Overview

## Confirmed configuration sources

### 1. Database config row

The main runtime settings are stored in `Sync.TableConfig`. `Get-ConfigRow` reads `c.*` from that table and joins it to `Sync.TableState`.

This is the primary control surface for:

- source and destination connection targets
- auth modes and credentials
- sync mode
- keys and watermark settings
- column selection
- retry and timeout behaviour
- auto-create and schema validation behaviour
- arbitrary destination-side SQL hooks

One important tuning field is `BatchSize`. In this repo it controls both source paging (`SELECT TOP (BatchSize)`) and bulk-copy chunking, so it depends on row width and LOB presence as well as row count. Use the table-analysis scripts in [Analyze Tables And Batch Sizing](../operations/analyze-table-batch-sizing.md) before changing it on a busy sync, and review [Batch Size Caveats](../operations/batch-size-caveats.md) for the trade-offs of small versus large batches.

New rows can also be created through `New-SyncTableConfig.ps1`, which guides operators through the confirmed runtime columns and validates several unsafe combinations before insert. That CLI is an operator convenience layer, not a separate source of truth; `Sync.TableConfig` remains the effective control plane.

### 2. Database state row

`Sync.TableState` is not static configuration, but it materially changes runtime behaviour in incremental mode. It holds:

- `LastWatermarkValue`
- `LastKeyValue`
- success/failure status
- last row counts
- consecutive failure count

Treat it as operational state, not a casual admin-edit surface.

### 3. Launcher script constants

Several launchers hard-code:

- config server
- config database
- config schema
- lists of `SyncName` values

These are part of the effective configuration model even though they are not in the database.

### 4. CLI parameters

The engine accepts:

- `-ConfigServer`
- `-ConfigDatabase`
- `-ConfigSchema`
- `-SyncId`
- `-SyncName`
- auth options for the config connection
- `-EncryptConnection`
- `-TrustServerCertificate`
- `-PrintSql`

These affect the control database connection and process-level behaviour.

### 5. API and MCP server parameters

`Start-SqlTablesSyncRestApi.ps1` and `Start-SqlTablesSyncMcpServer.ps1` add process-level settings for local automation access.

Confirmed settings:

- the same config-database connection parameters used by the engine
- `ListenPrefix` for the REST API
- `MaxRequestBodyBytes` for the REST API
- `NodeExecutable` for launching the Node host

Important note:

- No new `Sync.TableConfig` or `Sync.TableState` fields were added for these features.
- These settings live only in the process invocation, not in the database control plane.
- Storage location for `NodeExecutable`: process parameter on `Start-SqlTablesSyncRestApi.ps1` and `Start-SqlTablesSyncWorkspace.ps1`.
- Valid values for `NodeExecutable`: executable name on `PATH` such as `node`, or an absolute path to a Node.js executable.
- Default for `NodeExecutable`: `node`.
- Code paths affected: `Start-SqlTablesSyncRestApi.ps1`, `Start-SqlTablesSyncWorkspace.ps1`.
- Operational risk: if `NodeExecutable` points to the wrong runtime or `webapp/node_modules` is missing, the dashboard and REST API will not start.
- Safe change procedure: confirm `node --version`, run `npm install` in `webapp`, start on loopback, validate `GET /health`, then open `/`.
- Storage location for `DotNetExecutable`: process parameter on `Start-SqlObjectSearchService.ps1` and `Start-SqlTablesSyncWorkspace.ps1`.
- Valid values for `DotNetExecutable`: executable name on `PATH` such as `dotnet`, or an absolute path to `dotnet.exe`.
- Default for `DotNetExecutable`: empty in `Start-SqlTablesSyncWorkspace.ps1`, which means `Start-SqlObjectSearchService.ps1` falls back to `dotnet`.
- Code paths affected: `Start-SqlObjectSearchService.ps1` and `Start-SqlTablesSyncWorkspace.ps1`.
- Operational risk: if `DotNetExecutable` points to the wrong runtime or no .NET runtime is installed, the Lucene.NET object-search sidecar will not start and schema sync plus command-palette database search will fail.
- Safe change procedure: confirm `dotnet --info` or the explicit executable path first, start the workspace on loopback, validate the `Object search service` health check, then run one low-risk schema sync.
- Download source for .NET when it is missing: `https://dotnet.microsoft.com/en-us/download/dotnet`

### 6. Local object-search settings

The database object search feature adds one local JSON settings file:

- storage location:
  `object-search/sql-object-search.settings.json`
- valid values:
  `service.listenUrl` must be a loopback HTTP URL, `service.executablePath` may be blank or a relative or absolute path to a bundled `SqlObjectSearch.Service.exe`, `service.indexRoot` and `sync.*Path` values must resolve to writable local paths, `sync.batchSize` must be a positive integer, and each source row must contain a SQL Server name, database name, and auth mode
- defaults:
  `service.listenUrl = http://127.0.0.1:8094/`, `service.executablePath = ./bin/win-x64/SqlObjectSearch.Service.exe`, `service.maxResults = 40`, `service.snippetLength = 240`, `sync.batchSize = 200`
- code paths affected:
  `Start-SqlObjectSearchService.ps1`, `Publish-SqlObjectSearchService.ps1`, `Sync-SqlObjectSearchIndex.ps1`, `object-search/SqlObjectSearch.Service/Program.cs`, `webapp/server.js`, and `webapp/components/object-search-palette.js`
- operational risk:
  medium, because the local index persists SQL object names, definitions, columns, parameters, and dependency names on disk, and a stale or missing bundled executable path can stop the sidecar from starting
- safe change procedure:
  keep the service on loopback, run `.\Publish-SqlObjectSearchService.ps1` when updating the bundled sidecar, confirm the workspace or sidecar launcher prefers the bundled executable, run one incremental refresh, validate `GET /api/object-search/status`, and only then expand the scope
- confidence:
  confirmed for file locations, defaults, and the loopback service binding; inferred for some edge-case incremental coverage on child objects because SQL Server does not expose a native tombstone stream for columns and indexes

### 7. Local auth and user-preference database

SQL Cockpit now has one packaged local SQLite database for workstation-local sign-in and user preference storage.

- storage location:
  `data/sql-cockpit/sql-cockpit-local.sqlite`
- valid values:
  `users.username` accepts the local username format enforced by `webapp/lib/local-auth.js`; `users.role` currently defaults to `admin`; `user_preferences.preference_key` currently uses `theme`, `focusMode`, `notificationPreferences`, `connectionProfiles`, and `instanceProfiles`; `focusMode` stores a boolean that enables the distraction-reduced dashboard shell; `sessions.expires_at_utc` stores UTC timestamps; the browser cookie name is `sql_cockpit_session`
- defaults:
  first workstation user is created through `/setup`; default session lifetime is 7 days with rolling touch; lockout threshold is 5 failed logins in 15 minutes; default `theme = dark`; default `focusMode = false`; notification and saved-profile preference stores start empty or false-like
- code paths affected:
  `webapp/lib/local-auth.js`, `webapp/server.js`, `webapp/components/dashboard-client.js`, `webapp/components/dashboard-shell.js`, `webapp/components/dashboard-data.js`, `webapp/app/login/page.js`, `webapp/app/setup/page.js`, and `webapp/app/preferences/page.js`
- operational risk:
  medium, because the local app database now contains workstation-local auth state and may also contain saved SQL-auth connection passwords through the per-user preference store; low for `focusMode` itself because it changes presentation rather than API behavior, but operators should confirm they can still find hidden chrome such as breadcrumbs and the footer when they leave focus mode
- safe change procedure:
  back up the SQLite file before incompatible schema changes, keep the app on loopback, validate first-run setup, login, logout, password change, focus-mode toggle persistence, and preference persistence after deployment, and prefer integrated SQL authentication in saved profiles whenever possible
- confidence:
  confirmed for the storage path, session cookie name, password hashing, rate limit values, and current preference keys; inferred that future hardening may add a stronger machine-bound encryption layer for saved SQL-auth profile passwords

### 8. Legacy browser-local preference migration

The dashboard still reads older browser-local profile data once during migration so existing operators are not forced to recreate saved connections immediately.

- storage location:
  legacy browser local storage keys `sql-cockpit-database-connection-profiles`, `sql-cockpit-instance-profiles`, `sql-cockpit-connection-profiles`, and `sql-cockpit-theme`
- valid values:
  JSON arrays for saved profiles and a string theme value of `light` or `dark`
- defaults:
  migration only runs when the new local preference store is empty for the corresponding key
- code paths affected:
  `webapp/components/dashboard-client.js`
- operational risk:
  low to medium, because one-time migration can bring previously browser-stored SQL-auth profile values into the packaged local database
- safe change procedure:
  sign in once after upgrading, confirm the expected saved profiles appear in Connection Manager and Instance Manager, then retire the old browser profile only after the migrated data has been validated
- confidence:
  confirmed for the migration keys and fallback order

## High-risk interactions

- `SyncMode=FullRefresh` plus a production destination table.
- very large `BatchSize` on a wide or LOB-heavy source table.
- `KeyColumnsCsv` that does not uniquely identify rows.
- watermark settings that do not match the source change pattern.
- `SourceWhereClause` that silently removes required rows.
- `PreSyncSql` or `PostSyncSql` with unreviewed side effects.
- connection target changes that redirect to the wrong environment.
- exposing the REST API beyond `127.0.0.1` without reviewing credential exposure.

## Safe editing rules

- Prefer changing one field at a time.
- Capture the old row before editing it.
- Do not edit `Sync.TableState` while a sync is running.
- For any high-risk change, validate with a single manual run before re-enabling scheduled execution.
- For `BatchSize` changes, profile the source table first and start with the conservative end of the suggested range.
