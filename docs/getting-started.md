# Getting Started

This page is the front door to the docs.

If you want the structure to feel more like a polished product manual, use the docs in this order:

1. `Home` for orientation and setup.
2. `User Documentation` for day-to-day SQL Cockpit work.
3. `Developer Documentation` for internals, contracts, and maintenance.

## Choose your track

| If you are trying to... | Start here |
| --- | --- |
| open the app and use it safely | [User Documentation](user/index.md) |
| understand the dashboard pages | [User Documentation](user/dashboard-guide.md) |
| manage instance or connection profiles | [User Documentation](user/connection-and-instance-profiles.md) |
| create or review sync rows | [User Documentation](user/sync-configuration-workflow.md) |
| change code or troubleshoot a route | [Developer Documentation](developer/index.md) |
| understand how the runtime fits together | [Developer Documentation](developer/system-map.md) |
| maintain docs and generated reference pages | [Developer Documentation](developer/documentation-maintenance.md) |

## Repository shape

The repository is a script runner, not a compiled application. The main files are:

- `Sync-ConfiguredSqlTable.ps1`: core sync engine.
- `New-SyncTableConfig.ps1`: interactive CLI for inserting new `Sync.TableConfig` rows.
- `Spawn-AptosJobs.ps1`, `Spawn-AptosJobsMemorySafe.ps1`, `Spawn-AptosJobsMemorySafe.Child.ps1`: Aptos-oriented launchers.
- `Spawn-SyncJobs.ps1`: remote sync launcher.
- `Analyze-RunLogs.ps1`: local run-log summary tool for launcher and child sync logs.
- `Adhoc_RunJobs.ps1`: alternate memory-aware launcher for a hard-coded remote job list.
- `Test-Connection.ps1`, `TestLogin.ps1`: ad hoc connection tests. Treat them as sensitive.
- `webapp/`: Next.js web app and Node host for `SQL Cockpit`.

## Prepare the dashboard runtime

From the repo root:

```powershell
cd webapp
npm install
```

Observed behavior:

- confirmed: the dashboard now depends on Node.js plus the `webapp/package.json` dependencies.
- confirmed: the dashboard shell now depends on Tailwind CSS PostCSS tooling in addition to `next`, `react`, and `react-dom`.
- confirmed: the PowerShell layer still provides the SQL business logic, but it no longer hosts HTTP directly.
- confirmed: when `webapp/.next/BUILD_ID` exists, `webapp/server.js` now prefers production mode automatically unless `NODE_ENV` is explicitly set, which avoids stale development-cache failures after a completed build.
- confirmed: `npm run build` now checks for the dev-mode lock written by `Start-SqlTablesSyncRestApi.ps1 -DevMode` before building and clears stale `.next` output first, so production builds do not collide with hot-reload state by default.
- inferred: if `node_modules/` is missing, `Start-SqlTablesSyncRestApi.ps1` will fail fast before opening a listener.

## Build the docs

From the repo root:

```powershell
cd docs
pip install -r requirements-docs.txt
powershell -File scripts/generate_config_docs.ps1
mkdocs serve
```

Or use:

```powershell
powershell -File docs/scripts/build_docs.ps1
```

This now runs one build and then keeps watching `docs/` and `mkdocs.yml` for changes, rebuilding the generated site automatically until you stop it with `Ctrl+C`.

For a single one-off build, use:

```powershell
powershell -File docs/scripts/build_docs.ps1 -Once
```

To host the docs site locally, including Material search in a browser, use:

```powershell
powershell -File .\Start-SqlTablesSyncDocsServer.ps1
```

Observed behavior:

- confirmed: when Python and MkDocs are available, the script runs `mkdocs serve` with live reload.
- confirmed: when MkDocs is not available but `site/` already exists, the script falls back to a lightweight local HTTP server so Material search can still load `search_index.json`.
- inferred: if both Python and a fresh site build are missing, you will need to build once on a machine with MkDocs installed before the fallback host is useful.

To start the docs site, the REST API, and the browser web app entry point together, use:

```powershell
powershell -File .\Start-SqlTablesSyncWorkspace.ps1 `
  -ConfigServer "YOUR_SQL_SERVER" `
  -ConfigDatabase "YOUR_CONFIG_DATABASE" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate
```

Observed behavior:

- confirmed: this launcher starts `Start-SqlTablesSyncDocsServer.ps1` and `Start-SqlTablesSyncRestApi.ps1` as separate child processes.
- confirmed: the `SQL Cockpit` web app is reached through the Node-hosted REST API root at `http://127.0.0.1:8080/`.
- confirmed: the launcher writes stdout and stderr logs for both child processes under `.\Logs`.
- confirmed: the web app now writes browser and Node-side troubleshooting traces under `.\Logs\WebApp` as newline-delimited JSON files.

## Runtime prerequisites

- PowerShell on Windows.
- Node.js for the dashboard and local HTTP server.
- Network connectivity to the config, source, and destination SQL Servers.
- Access to the config database passed through `-ConfigServer`, `-ConfigDatabase`, and `-ConfigSchema`.
- SQL permissions sufficient for:
  - reading `Sync.TableConfig`
  - reading and updating `Sync.TableState`
  - inserting `Sync.RunLog`
  - inserting `Sync.RunActionLog`
  - reading source tables
  - writing destination tables
  - creating temp tables in `tempdb`

## First files to read

1. `Sync-ConfiguredSqlTable.ps1`
2. `docs/database/config-tables.md`
3. `docs/configuration/overview.md`
4. `docs/operations/create-sync-jobs-with-cli.md`
5. `docs/operations/runbooks.md`

## First operational checks

Before running a sync against a new environment, confirm:

- The launcher points at the intended config database.
- The new row was created through `New-SyncTableConfig.ps1` or an equivalent reviewed SQL change.
- The `SyncName` exists in `Sync.TableConfig`.
- `SourceAuthMode` and `DestinationAuthMode` match the available credentials.
- `KeyColumnsCsv`, `SyncMode`, and watermark fields match the source table behaviour.
- `PreSyncSql` and `PostSyncSql` are empty or reviewed.
