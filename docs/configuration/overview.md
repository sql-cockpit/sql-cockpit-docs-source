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

`Start-SqlTablesSyncRestApi.ps1` and `scripts/runtime/Start-SqlTablesSyncMcpServer.ps1` add process-level settings for local automation access.

Confirmed settings:

- MCP wrapper settings such as `ApiBaseUrl`, `ApiUsername`, `ApiSessionToken`, and `ApiTimeoutMs`
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

The database object search feature uses tracked safe defaults plus a local override:

- storage location:
  tracked safe settings at `sql-cockpit-object-search/sql-object-search.settings.template.json` and `sql-cockpit-object-search/sql-object-search.settings.json`; operator-local override at `sql-cockpit-object-search/sql-object-search.settings.local.json`
- valid values:
  `service.listenUrl` must be a loopback HTTP URL, `service.executablePath` may be blank or a relative or absolute path to a bundled `SqlObjectSearch.Service.exe`, `service.indexRoot` and `sync.*Path` values must resolve to writable local paths, `sync.batchSize` must be a positive integer, and each source row must contain a SQL Server name, database name, and auth mode
- defaults:
  `service.listenUrl = http://127.0.0.1:8094/`, `service.executablePath = ./bin/win-x64/SqlObjectSearch.Service.exe`, `service.maxResults = 40`, `service.snippetLength = 240`, `sync.batchSize = 200`, `sync.manifestDirectory = ./data/object-search/manifests`, `sync.spoolDirectory = ./data/object-search/spool`, `sync.statusPath = ./data/object-search/sync-status.json`, `sync.logPath = ./Logs/ObjectSearch/sync.log`
- compatibility note:
  `service.snippetLength` is retained for older settings files, but current search result rows do not load definition text or build definition snippets. Definitions are loaded only through the selected-object detail API.
- code paths affected:
  `Start-SqlObjectSearchService.ps1`, `Publish-SqlObjectSearchService.ps1`, `Sync-SqlObjectSearchIndex.ps1`, `sql-cockpit-object-search/SqlObjectSearch.Service/Program.cs`, `sql-cockpit-api/server.js`, and `sql-cockpit-api/components/object-search-palette.js`
- operational risk:
  medium, because the local index persists SQL object names, definitions, columns, parameters, and dependency names on disk, and a stale or missing bundled executable path can stop the sidecar from starting; high if local credential-bearing settings are committed by mistake
- safe change procedure:
  keep the service on loopback, copy `sql-object-search.settings.local.json.example` to `sql-object-search.settings.local.json`, run `.\Publish-SqlObjectSearchService.ps1` when updating the bundled sidecar, confirm the workspace or sidecar launcher prefers the local override, run one full bootstrap sync, then run incremental refresh for steady state, validate `GET /api/object-search/status`, and only then expand the scope
- confidence:
  confirmed for file locations, defaults, and the loopback service binding; inferred for some edge-case incremental coverage on child objects because SQL Server does not expose a native tombstone stream for columns and indexes

### 7. Local auth and user-preference database

SQL Cockpit now has one packaged local SQLite database for workstation-local sign-in and user preference storage.

- storage location:
  `data/sql-cockpit/sql-cockpit-local.sqlite`
- valid values:
  `users.username` accepts the local username format enforced by `sql-cockpit-api/lib/rbac-auth-store.js`; `user_preferences.preference_key` currently uses `theme`, `focusMode`, `notificationPreferences`, `connectionProfiles`, `instanceProfiles`, `activeWorkspace`, `visualServerExplorerSettings`, `sourceControlSettings`, `profilePicture`, `commandPaletteDefaultMode`, `defaultPage`, `welcomePageLayout`, and `dashboardIntroPanels`; `sourceControlSettings` stores a signed-in user's Git repository path and default SQL object types for Source Control snapshots; `profilePicture` stores an optional compressed multi-size avatar object for the signed-in user; `welcomePageLayout` stores compact welcome-page widget order, collapsed state, CSS-grid-style `responsiveColSpans` for mobile, tablet, and desktop breakpoints, `rowSpan` sizing, and clock/greeting display settings such as `timeFormat`, `dateStyle`, `showSeconds`, `textScale`, and `theme`; mobile `responsiveColSpans` default to `12` columns so saved dashboards stack cleanly on phones unless the user intentionally changes mobile widget widths; supported welcome widgets include the workspace-scoped `recentObjectCache` widget, which reads instance/database filter metadata from compact `GET /api/object-search/status?compact=1`, reads displayed rows from `GET /api/object-search/recent`, and stores optional `objectType`, `sourceServer`, `databaseName`, and `limit` filters in widget settings; `objectCacheInsights`, `cacheLargestDatabases`, `cacheFreshness`, `cacheSyncActivity`, and the status-backed object-cache graph widgets summarize the compact object-search status payload; `changeMix` and recent-change graph widgets read `GET /api/object-search/recent?limit=50&perTypeLimit=5` and summarize recent changes by object type; `objectTypeCounts` and type graph widgets read `GET /api/object-search/analytics/object-types` for workspace-scoped total indexed counts by type; the `runningTasks` widget reads visible running rows from `GET /api/task-runs?status=running`; the `nextTasks` widget reads upcoming visible task definitions from `GET /api/tasks?nextRun=scheduled`; `taskHealth` reads visible tasks from `GET /api/tasks?limit=500`; `dashboardIntroPanels` stores per-section intro-panel expanded state and defaults to collapsed when unset; `notificationPreferences.teamSyncFailureNotificationsEnabled` and `notificationPreferences.syncFailureEmailEnabled` default to `true`; `focusMode` stores a boolean that enables the distraction-reduced dashboard shell; `sessions.expires_at` stores UTC timestamps; the browser cookie name is `sql_cockpit_session` and it is issued as `HttpOnly`, `SameSite=Lax`, with `Max-Age` and `Expires`
- defaults:
  first workstation user is created through `/setup`; default session lifetime is 7 days with rolling touch, and the cookie is reissued when the server renews a valid session after at least 15 minutes since `last_seen_at`; lockout threshold is 5 failed logins in 15 minutes; default `theme = dark`; default `focusMode = false`; browser notification permission starts disabled, while sync-failure team alerts and creator email preferences start enabled
- code paths affected:
  `sql-cockpit-api/lib/rbac-auth-store.js`, `sql-cockpit-api/server.js`, `sql-cockpit-api/lib/task-management-store.js`, `sql-cockpit-api/components/dashboard-client.js`, and `sql-cockpit-api/components/notifications-data.js`
- operational risk:
  medium, because the local app database now contains workstation-local auth state and may also contain saved SQL-auth connection passwords through the per-user preference store; low for `focusMode` itself because it changes presentation rather than API behavior, but operators should confirm they can still find hidden chrome such as breadcrumbs when they leave focus mode
- safe change procedure:
  back up the SQLite file before incompatible schema changes, keep the app on loopback, validate first-run setup, login, logout, password change, focus-mode toggle persistence, and preference persistence after deployment, and prefer integrated SQL authentication in saved profiles whenever possible
- confidence:
  confirmed for the storage path, session cookie name, password hashing, rate limit values, sync-failure notification preferences, and current preference keys; inferred that future hardening may add a stronger machine-bound encryption layer for saved SQL-auth profile passwords

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

