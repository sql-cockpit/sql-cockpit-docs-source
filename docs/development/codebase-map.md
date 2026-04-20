# Codebase Map

## Top-level files

- `Sync-ConfiguredSqlTable.ps1`: main engine and almost all business logic.
- `New-SyncTableConfig.ps1`: interactive config-row creation CLI for `Sync.TableConfig`.
- `Export-TableConfigDiagram.ps1`: read-only Graphviz exporter for `Sync.TableConfig` mappings.
- `Analyze-RunLogs.ps1`: read-only parser for local launcher and child sync log files.
- `Find-TableSyncConfig.ps1`: read-only filter for `Sync.TableConfig` rows by source or destination endpoint, with optional `BatchSize` advice.
- `Get-ServerObjects.ps1`: read-only live SQL Server inventory browser for the Server Explorer surface.
- `Get-TableBatchSizeRecommendation.ps1`: read-only live SQL table profiler for row width, storage, and advisory `BatchSize` ranges.
- `Sync-SqlObjectSearchIndex.ps1`: PowerShell SQL Server object-search sync pipeline that extracts metadata, builds Lucene document payloads, writes durable spool/checkpoint files, uploads batches to the local object-search sidecar, and writes manifests for stale-result cleanup.
- `Start-SqlObjectSearchService.ps1`: launcher for the local Lucene.NET object-search sidecar.
- `Publish-SqlObjectSearchService.ps1`: publishes the self-contained object-search sidecar executable for bundled deployment.
- `Test-RestApiEndpoint.ps1`: read-only REST-versus-PowerShell trace helper that probes one API route, runs the equivalent `Invoke-SqlTablesSyncRestOperation.ps1` operation directly, compares status and body hashes, and can write a local JSON trace file.
- `Start-SqlTablesSyncRestApi.ps1`: launcher that starts the Node-hosted HTTP API and Next.js dashboard.
- `Start-SqlTablesSyncDocsServer.ps1`: local docs host that prefers `mkdocs serve` and falls back to serving the built `site` folder.
- `Start-SqlTablesSyncWorkspace.ps1`: convenience launcher that starts the docs host and REST API together, with the webapp available from the API root.
- `Invoke-SqlTablesSyncRestOperation.ps1`: PowerShell request runner for config reads, writes, migration planning, and batch-size advice behind the Node host.
- `webapp/server.js`: custom Node server that serves Next.js, maps REST routes to the PowerShell request runner, bridges the dashboard to the local object-search sidecar, and auto-prefers production mode when a built `.next/BUILD_ID` exists.
- `webapp/lib/local-auth.js`: packaged local SQLite auth store for users, sessions, failed-login tracking, and per-user preference blobs; it also maps authenticated request context onto `users.id` while keeping `sessions.id` for session lifecycle only.
- `webapp/lib/client-error-reporting.js`: browser-side reporting helpers for unhandled exceptions, unhandled rejections, and handled dashboard failures.
- `webapp/package.json`: Node and Next.js runtime dependencies plus local scripts.
- `webapp/postcss.config.mjs`: Tailwind CSS v4 PostCSS bridge for the dashboard build.
- `webapp/app/layout.js`: root Next.js layout, metadata, and shared Outfit font for the SQL Cockpit web app.
- `webapp/app/error.js`: route-level fallback UI and logging hook for unexpected Next.js render failures.
- `webapp/app/page.js`: Estate Overview route for SQL Server instance capacity, health, database state, and SQL Agent summary.
- `webapp/app/login/page.js` and `webapp/app/setup/page.js`: route wrappers for the first-run local admin bootstrap and local sign-in screens.
- `webapp/app/preferences/page.js`: route entry for local account and password management.
- `webapp/app/sync-overview/page.js`: table-sync overview route. It reuses the previous sync KPI and attention content while the table sync tool is being moved into its own navigation section.
- `webapp/app/launchpad/page.js`, `webapp/app/connection-manager/page.js`, `webapp/app/instance-manager/page.js`, `webapp/app/agent-manager/page.js`, `webapp/app/fleet/page.js`, `webapp/app/inspector/page.js`, `webapp/app/server-explorer/page.js`, `webapp/app/schema-studio/page.js`, `webapp/app/batch-copilot/page.js`, `webapp/app/bulk-intake/page.js`: route entries for the split dashboard sections.
- `webapp/app/globals.css`: Tailwind-enabled global styles and the SQL Cockpit shell transitions and light-theme tokens.
- `webapp/components/dashboard-client.js`: SQL Cockpit composition, operator workflows, route transitions, server-backed preference persistence, command-palette object search, Estate Overview, the live Server Explorer page, SQL Agent Manager inventory view, Connection Manager and Instance Manager schema sync progress modal, minimized sync progress control, notifications, object-type icons, list/visual/graph views, and the add-server modal flow that applies explorer targets without persistence.
- `webapp/components/login-page-client.js` and `webapp/components/setup-page-client.js`: client-side auth forms for first-run setup and local login.
- `webapp/components/dashboard-data.js`: dashboard form definitions, payload mapping, and formatting helpers.
- `webapp/components/form-controls.js`: reusable field, toggle, and result-box primitives.
- `webapp/components/dashboard-shell.js`, `webapp/components/panel.js`, `webapp/components/stat-card.js`, `webapp/components/sync-table.js`: shared SQL Cockpit shell, theme toggle, authenticated user header actions, `Ctrl+K` search trigger, KPI cards, and mobile/desktop fleet-display components.
- `scripts/runtime/Start-SqlTablesSyncMcpServer.ps1`: MCP launcher wrapper that starts the `sql-cockpit-mcp-server` submodule.
- `SqlTablesSync.Tools.psm1`: shared SQL metadata and migration-planning module.
- `Spawn-AptosJobs.ps1`: Windows Terminal launcher for Aptos jobs.
- `Spawn-AptosJobsMemorySafe.ps1`: memory-aware launcher with concurrency control.
- `Spawn-AptosJobsMemorySafe.Child.ps1`: child wrapper that logs one job run to a file.
- `Spawn-SyncJobs.ps1`: simple remote launcher, currently non-starting because `Start-Process` is commented out.
- `Adhoc_RunJobs.ps1`: alternate memory-aware launcher for a remote job set.
- `Test-Connection.ps1`: ad hoc connection test with inline connection string.
- `TestLogin.ps1`: ad hoc login test with inline credentials.

## Main logical sections inside `Sync-ConfiguredSqlTable.ps1`

- logging and formatting helpers
- SQL connection and command helpers
- heartbeat and DMV diagnostics
- row conversion helpers for keys and watermarks
- config/state/log table helpers
- destination metadata and auto-create helpers
- incremental sync loop
- full refresh snapshot/stage/replace flow
- success/failure/final cleanup handling

## Where business rules live

Mostly inside `Sync-ConfiguredSqlTable.ps1`, especially:

- mode resolution
- key and watermark validation
- column selection
- upsert strategy
- full refresh safety checks
- checkpoint semantics

Migration-planning rules now live in `SqlTablesSync.Tools.psm1`, especially:

- SQL catalog inspection
- table profiling and advisory batch-size analysis
- column type rendering
- source/destination schema diffing
- migration SQL generation

## Where side effects occur

- inserts into `Sync.TableConfig`
- serves local HTML, CSS, and JavaScript assets for the browser UI
- serves Next.js in either production mode or explicit development watch mode for dashboard hot reload
- reads and writes the packaged local auth and preference SQLite database at `data/sql-cockpit/sql-cockpit-local.sqlite`
- serves local MkDocs documentation assets for browser access and Material search
- spawns local docs and API child processes and writes their logs under `.\Logs`
- writes local DOT and rendered diagram files
- reads local `.log` files and emits summaries
- reads config rows and live SQL metadata for table-analysis reports
- serves live read-only server-object inventory responses for the browser page and CLI script
- serves local HTTP responses
- reads and writes MCP stdio messages
- SQL reads from source
- writes to destination
- writes to `Sync.TableState`
- inserts into `Sync.RunLog`
- inserts into `Sync.RunActionLog`
- temp table creation in source and destination sessions

