# First Run

SQL Cockpit normally runs as a local workspace made of a PowerShell launcher, a Node-hosted dashboard and REST API, a Material for MkDocs documentation server, and optional object-search and notification services.

## Prerequisites

Before starting, confirm:

1. PowerShell can run local scripts.
2. Node.js is available for the dashboard.
3. The config database is reachable from this machine.
4. You know the config database server, database, and schema.
5. Your Windows account or SQL login can read the config tables.

The config database is the operational control plane. Most environments use a schema named `Sync`, with tables such as `Sync.TableConfig`, `Sync.TableState`, `Sync.RunLog`, and `Sync.RunActionLog`.

## Start The Workspace

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlTablesSyncWorkspace.ps1 `
  -ConfigServer "NASCAR" `
  -ConfigDatabase "EPC_Imports_PCK" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate
```

The launcher prints the dashboard and docs URLs. Keep the PowerShell window open while using the workspace.

## Launch Profiles (recommended)

For desktop runtime ownership, use explicit wrappers:

1. Development profile (`dev`, desktop owns components):

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.Dev.ps1" `
  -ConfigServer "<server>" `
  -ConfigDatabase "<database>" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate
```

2. Production client profile (`prod`, SCM host owns components):

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.ProdClient.ps1" `
  -ConfigServer "<server>" `
  -ConfigDatabase "<database>" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate `
  -ServiceHostControlUrl "http://127.0.0.1:8610/"
```

Read the full mode guide: [Runtime Modes: Development vs Production](runtime-modes.md).

## Open The Dashboard

Open the SQL Cockpit dashboard URL printed by the launcher. In the default local setup the REST API and dashboard are served from the same loopback host.

If this workstation has not been initialised yet, SQL Cockpit redirects to `/setup` so you can create the first local administrator account. After that, normal access begins at `/login`.

Use:

- `Estate Overview` for server capacity and health summaries.
- `Instance Manager` for reusable SQL Server instance profiles.
- `Connection Manager` for reusable database-level profiles.
- `Server Explorer` for live SQL catalog browsing.
- `SQL Agent Manager` for Agent job inspection and controlled job starts.
- `Fleet` and `Inspector` for sync row review.
- `Batch Copilot` for table profiling and `BatchSize` advice.

## Open The Documentation

The workspace also starts a docs host when configured to do so. If you only want docs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlTablesSyncDocsServer.ps1
```

The docs are one MkDocs site with audience prefixes:

- `/user/` for day-to-day use
- `/developer/` for maintainers

## First Checks

After the dashboard opens:

1. Complete `/setup` if prompted, then sign in.
2. Open `Preferences` and confirm the signed-in display name is correct.
3. Check `GET /health` through the browser or a REST client if the dashboard cannot load config data.
4. Save and test one low-risk instance in `Instance Manager`.
5. Save and test one low-risk database in `Connection Manager`.
6. Use `Fleet` or `Inspector` to confirm `Sync.TableConfig` rows are visible.
7. Keep new or imported sync rows disabled until they have been reviewed.

## Safe Defaults

- Keep the API bound to `127.0.0.1` unless a security review approves wider access.
- Prefer integrated security on operator workstations.
- Treat SQL-auth passwords in the local app database and `Sync.TableConfig` as sensitive.
- Preview config creates and CSV imports before committing them.
- Run against a low-risk database first when validating a new workstation or launcher change.
