# Local Development

This page collects the commands maintainers normally need while changing SQL Cockpit.

## Install Dashboard Dependencies

From the repo root:

```powershell
Push-Location .\webapp
npm install
Pop-Location
```

`npm install` now restores Electron as a local dev dependency for desktop-mode SQL Cockpit.

The webapp now also depends on the packaged local auth store created at runtime. A clean first-run path can be tested by deleting `data/sql-cockpit/sql-cockpit-local.sqlite` after taking a backup.

## Run The Full Workspace

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlTablesSyncWorkspace.ps1 `
  -ConfigServer "NASCAR" `
  -ConfigDatabase "EPC_Imports_PCK" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate
```

Use `-DevMode` when you need dashboard hot reload through the custom Node host.

- confirmed: if `webapp/.next/BUILD_ID` exists and you start the workspace without `-DevMode`, the launcher now prints a warning that frontend CSS and JavaScript edits will not auto-appear in the browser.
- safe change procedure: when editing files under `webapp/`, prefer the same workspace command with `-DevMode`, or run `npm run dev` from `webapp/`.

## Run Only The REST API And Dashboard

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlTablesSyncRestApi.ps1 `
  -ConfigServer "NASCAR" `
  -ConfigDatabase "EPC_Imports_PCK" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate `
  -ListenPrefix "http://127.0.0.1:8080/"
```

- confirmed: if `webapp/.next/BUILD_ID` exists and you start this launcher without `-DevMode`, it now warns that the dashboard will prefer production output and frontend file edits will not hot-reload.

## Run Managed API From Split Folder

The API runtime is now mirrored into `sql-cockpit-api/` so it can be initialized as a separate repository.

```powershell
Push-Location .\sql-cockpit-api
npm ci
npm run build
npm run start -- --configServer "NASCAR" --configDatabase "EPC_Imports_PCK" --configSchema "Sync" --configIntegratedSecurity --trustServerCertificate --listenPrefix "http://127.0.0.1:8000/" --notificationsListenPrefix "http://127.0.0.1:8090/" --runtimeProfile "prod" --manageComponents "false" --serviceHostControlUrl "http://127.0.0.1:8610/"
Pop-Location
```

Refresh the mirrored API folder from current `webapp` sources:

```powershell
powershell -ExecutionPolicy Bypass -File .\Sync-SqlCockpitApiRepo.ps1
```

## Run The Desktop App (Electron)

Use the desktop launcher when you want SQL Cockpit in a standalone window instead of a browser tab.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlCockpitDesktop.ps1 `
  -ConfigServer "NASCAR" `
  -ConfigDatabase "EPC_Imports_PCK" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate
```

Runtime config is passed to Electron through process environment variables:

- `SQL_COCKPIT_CONFIG_SERVER`
- `SQL_COCKPIT_CONFIG_DATABASE`
- `SQL_COCKPIT_CONFIG_SCHEMA`
- `SQL_COCKPIT_CONFIG_USERNAME`
- `SQL_COCKPIT_CONFIG_PASSWORD`
- `SQL_COCKPIT_CONFIG_INTEGRATED_SECURITY`
- `SQL_COCKPIT_ENCRYPT_CONNECTION`
- `SQL_COCKPIT_TRUST_SERVER_CERTIFICATE`
- `SQL_COCKPIT_LISTEN_PREFIX`
- `SQL_COCKPIT_NOTIFICATIONS_LISTEN_PREFIX`
- `SQL_COCKPIT_MAX_REQUEST_BODY_BYTES`
- `SQL_COCKPIT_OBJECT_SEARCH_SETTINGS_PATH`

The desktop launcher now also starts the same sidecar services the workspace launcher starts:

- docs server (`Start-SqlTablesSyncDocsServer.ps1`)
- notifications server (`Start-SqlTablesSyncNotificationsServer.ps1`)
- object-search service (`Start-SqlObjectSearchService.ps1`)

Service behavior notes:

- defaults match the workspace launcher: docs `http://127.0.0.1:8000/`, notifications `http://127.0.0.1:8090/`, object-search from `object-search/sql-object-search.settings.json`
- if a default docs/API/notifications port is unavailable and you did not pass it explicitly, the desktop launcher probes nearby loopback ports and logs the resolved value
- readiness checks now run before Electron starts (`docs`, `notifications /health`, `object-search /health`) and the launcher prints stdout and stderr log paths for each sidecar
- for prod client mode with SCM-hosted API, set `-ManageComponents false` and `-ExternalApiOnly true` so desktop connects to managed API (`:8000`) instead of spawning embedded API

Safe change procedure:

- prefer the PowerShell launcher so required config arguments are explicit
- use `-DevMode` while editing `webapp/` to start Electron with `--dev` on the custom Node host

## Desktop App Dev Watch Mode

For fast iteration on the desktop app without packaging:

```powershell
Push-Location .\webapp
npm install
npm run dev:watch -- --dev
Pop-Location
```

This uses `webapp/electron/build/dev-watch.js` to restart Electron on changes to `webapp/electron/**` and `webapp/server.js`.

## Desktop App Build And Release (GitHub Releases)

The desktop app release workflow mirrors the Service Control app build system:

1. update `webapp/package.json` version
2. tag `desktop-vX.Y.Z`
3. GitHub Actions builds and publishes NSIS installer

Local build:

```powershell
Push-Location .\webapp
npm ci
npm run build
npm run dist:desktop
Pop-Location
```

If `npm ci` fails with `EBUSY` on `webapp\node_modules\electron\dist\icudtl.dat`, close running Electron/Node processes and clear the dev lock before retrying:

```powershell
Get-Process -Name "electron","node","SQL Cockpit" -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath ".\webapp\.sql-cockpit-dev-lock.json" -ErrorAction SilentlyContinue
Push-Location .\webapp
npm ci
Pop-Location
```

Portable build (no auto-update support):

```powershell
Push-Location .\webapp
npm run dist:desktop:portable
Pop-Location
```

Notes:

- `webapp/electron/build/run-electron-builder.js` now invokes Electron Builder through the Node CLI entrypoint instead of `.cmd` wrappers to avoid Windows `spawnSync ... EINVAL` failures.

### Desktop Build Modes (Portable vs Production)

Use this decision guide during development:

1. Portable build (`dist:desktop:portable`):
- best for local testing and sharing a single EXE quickly
- does not support `electron-updater` auto-updates
- output includes `SQL Cockpit portable.exe`

2. Production build (`dist:desktop`):
- builds NSIS installer (`SQL Cockpit setup.exe`)
- required for in-app auto-update via GitHub Releases
- use this path for release candidates and production rollouts

### Portable Build (Development / Test)

```powershell
Push-Location .\webapp
npm ci
npm run build
npm run dist:desktop:portable
Pop-Location
```

Expected output:

- timestamped folder under `webapp\publish\desktop-YYYYMMDD-HHMMSS\`
- portable executable `SQL Cockpit portable.exe`

Run the portable app in dev mode:

```powershell
.\webapp\publish\desktop-YYYYMMDD-HHMMSS\SQL Cockpit portable.exe --dev
```

### Production Build (Installer + Auto-Updates)

```powershell
Push-Location .\webapp
npm ci
npm run build
npm run dist:desktop
Pop-Location
```

Expected output:

- timestamped folder under `webapp\publish\desktop-YYYYMMDD-HHMMSS\`
- installer `SQL Cockpit setup.exe`

Production release steps:

1. bump version in `webapp/package.json`
2. commit and push
3. create tag `desktop-vX.Y.Z`
4. push tag to trigger `.github/workflows/release-desktop-app.yml`
5. install from release artifact and verify update checks in packaged app

Operational caveat:

- if you test update behavior with portable builds, update checks will be skipped because only installed/packaged app flows support `electron-updater`.

## Split Node Modules (Electron vs Web API ABI)

The desktop Electron runtime can require a different Node ABI than the system Node that runs the web API. To prevent native module crashes (for example `better-sqlite3` ABI mismatches), the webapp now supports separate module folders:

- `webapp/node_modules`: used by the web API when launched with system Node (service host, workspace, REST-only mode).
- `webapp/node_modules_electron`: used when Electron runs the embedded API (`webapp/electron/main.js` injects a module-path hook).

Setup steps:

```powershell
Push-Location .\webapp
npm ci
npm run deps:electron
Pop-Location
```

Notes:

- confirmed: `npm run deps:electron` copies `node_modules` to `node_modules_electron` and runs `electron-rebuild` against the copied modules.
- confirmed: desktop packaging includes `node_modules_electron` when present, but installer builds do not require `deps:electron` to run first (Electron Builder handles native rebuilds during packaging).
- safe change procedure: rerun `npm run deps:electron` after changing native dependencies or updating Electron versions.
- operational risk: if `node_modules_electron` is missing, the embedded API will log a warning and fall back to `node_modules`, which can reintroduce ABI mismatch errors.

Manual ABI validation:

```powershell
Push-Location .\webapp

# Web API under system Node (expects node_modules ABI)
node server.js --configServer NASCAR --configDatabase EPC_Imports_PCK --configSchema Sync --configIntegratedSecurity --trustServerCertificate --listenPrefix http://127.0.0.1:8000/ --notificationsListenPrefix http://127.0.0.1:8090/ --docsListenPrefix http://127.0.0.1:8001/ --runtimeProfile prod --manageComponents false --serviceHostControlUrl http://127.0.0.1:8610/

# Electron embedded API path (expects node_modules_electron ABI)
npm run electron:dev

Pop-Location
```

For split-repository API ownership and service-host managed API contracts, see [API Repository Split (Desktop + Managed API)](api-repository-split.md).

Desktop launcher parameter compatibility note:

- confirmed: `Start-SqlCockpitDesktop.ps1` now accepts boolean-like values for `ManageComponents`, `ComponentAutoStart`, and `ComponentAutoRestart` as `true/false` or `0/1` (including string inputs from service-host JSON args).
- safe change procedure: when launching through service settings args, prefer `"false"` / `"true"` for these values.

## Run Only Docs

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SqlTablesSyncDocsServer.ps1
```

The docs host prefers `mkdocs serve` when available and can fall back to serving the built `site` folder.

## Capture Docs Screenshots

The screenshot capture script now signs in through the local dashboard login before it captures protected pages.

```powershell
$env:SCREENSHOT_USERNAME = "docs_screens"
$env:SCREENSHOT_PASSWORD = "replace-with-local-screenshot-password"
node .\docs\scripts\capture-doc-screenshots.mjs --base-url http://127.0.0.1:8080
```

Safe change procedure:

- use a low-risk local screenshot account or sanitized auth-store snapshot
- prefer environment variables over `--password` so secrets do not land in shell history
- review generated images under `docs/assets/screenshots/` before committing them

## Build The Dashboard

```powershell
Push-Location .\webapp
npm run build
Pop-Location
```

`npm run build` now runs a lightweight prebuild step that clears stale `.next` output, then runs `next build` (no dev-lock guard or override flag).

## Reset Service Control Dev Environment (Windows)

Use this when you need a clean installer test cycle for SQL Cockpit Service Control:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\service\windows\Reset-SqlCockpitServiceControlDevEnvironment.ps1
```

What it resets:

- running tray/app processes (`SQL Cockpit Service Control.exe`, `electron.exe`, `node.exe`)
- scheduled tasks (`SQLCockpitServiceTrayAtLogon` and legacy `SQLCockpitServiceControlAtLogon`)
- Windows service `SQLCockpitServiceHost`
- registered uninstall entries and common local install folders
- service settings file under `%ProgramData%\SqlCockpit\sql-cockpit-service.settings.json` (unless `-KeepServiceSettings` is passed)
- service publish output under `service\publish\win-x64` (unless `-SkipPublishCleanup` is passed)

Example preserving settings:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\service\windows\Reset-SqlCockpitServiceControlDevEnvironment.ps1 -KeepServiceSettings
```

Operational notes:

- this script requires an elevated PowerShell session (Run as Administrator)
- this is development cleanup tooling; do not run it on shared production hosts without change control

## Service Control Release Caveats (Installer vs App Update)

When changing the separate Service Control repository, use this decision rule:

1. app-only UI or renderer/main-process behavior changes:
- publish a normal GitHub release tag (for example `v1.0.3`)
- existing installed clients can update through `Check For Updates`

2. installer/provisioning/packaging changes:
- examples: NSIS hooks, service registration scripts, scheduled-task setup behavior, bundled resources
- publish a new installer and validate with a fresh install path (clean machine or dev reset script)
- do not rely only on in-app updater validation for installer-level behavior

Operational risk:

- app updates and installer provisioning are related but not equivalent. A successful in-app update does not prove first-install provisioning behavior for service/task registration.

Safe change procedure:

1. test app update flow from N-1 to N in packaged app
2. separately test clean install of N with installer provisioning checks (`SQLCockpitServiceHost`, `SQLCockpitServiceTrayAtLogon`, `http://127.0.0.1:8610/health`)
3. document any installer-only caveats in ops docs before rollout

## Service Control UI Dev Watch Mode (No GitHub Release Required)

For local iteration on the separate Service Control Electron UI:

```powershell
cd .\service\windows\SqlCockpit.ServiceControl.Electron
npm install
npm run dev:watch -- --settings "C:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json"
```

What this does:

- starts SQL Cockpit Service Control from source
- watches `main.js`, `preload.js`, and `renderer/*`
- automatically restarts Electron when watched files change

When to use this:

- frontend and renderer changes (buttons, layout, status labels)
- Electron main/preload changes during local development
- rapid iteration without packaging installers or publishing to GitHub

Operational note:

- watch mode is development-only and does not test installer behavior, auto-update release feeds, or packaged startup/task/service provisioning.
- if you need full elevated launcher behavior for service actions during dev, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\service\windows\Start-SqlCockpitServiceControlElectron.ps1 `
  -SettingsPath "C:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json" `
  -RunAsAdministrator
```

## Suite Installer Build (Single End-User Installer)

The canonical end-user installer is now the Service Control NSIS package, which bundles desktop setup and provisions the full suite.

Build steps:

```powershell
cd .\service\windows
powershell -ExecutionPolicy Bypass -File .\Prepare-SqlCockpitSuiteDesktopBundle.ps1
powershell -ExecutionPolicy Bypass -File .\Publish-SqlCockpitServiceControlElectron.ps1
```

If desktop setup auto-discovery fails:

```powershell
powershell -ExecutionPolicy Bypass -File .\Publish-SqlCockpitServiceControlElectron.ps1 `
  -DesktopSetupPath "C:\path\to\SQL Cockpit setup.exe"
```

Support/repair entrypoints:

- `service/windows/Install-SqlCockpitSuite.ps1`
- `service/windows/Repair-SqlCockpitSuite.ps1`

## Rebuild Decision Guide (What To Run For Which Change)

Use this matrix to decide whether you need to rebuild installers, or only restart local runtime.

| Change type | Rebuild needed? | What to run |
| --- | --- | --- |
| Service Control renderer/main/preload change (buttons, UI text, IPC wiring) while using `npm run dev:watch` | No installer rebuild for local dev | run `npm run dev:watch` in `service/windows/SqlCockpit.ServiceControl.Electron` |
| Service Control change and you want the installed app under `Program Files` to include it | Rebuild Service Control installer | in `service/windows/SqlCockpit.ServiceControl.Electron`: `npm ci`, `npm run dist`, then run new installer |
| Desktop app UI/server/electron change and you want installed `SQL Cockpit.exe` updated | Rebuild Desktop installer | in `webapp`: `npm ci`, `npm run build`, `npm run dist:desktop`, then run new desktop installer |
| Service host (.NET) or suite provisioning script change (`Install-*`, `Repair-*`, task/service setup) | Rebuild suite installer and reprovision | in `service/windows`: `Prepare-SqlCockpitSuiteDesktopBundle.ps1`, `Publish-SqlCockpitServiceControlElectron.ps1`, then run installer and `Repair-SqlCockpitSuite.ps1` if needed |
| Live runtime setting update only in `C:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json` | No installer rebuild | `Restart-Service SQLCockpitServiceHost` |
| Default/template setting update in `service/windows/sql-cockpit-service.settings.json` for future installs | Rebuild suite installer for distribution; no immediate effect on existing installs | rebuild suite installer; existing installs require `Repair-SqlCockpitSuite.ps1` or manual ProgramData update |

Quick command blocks:

Service Control installer rebuild:

```powershell
cd .\service\windows\SqlCockpit.ServiceControl.Electron
npm ci
npm run dist
```

Desktop installer rebuild:

```powershell
cd .\webapp
npm ci
npm run build
npm run dist:desktop
```

Suite installer rebuild:

```powershell
cd .\service\windows
powershell -ExecutionPolicy Bypass -File .\Prepare-SqlCockpitSuiteDesktopBundle.ps1
powershell -ExecutionPolicy Bypass -File .\Publish-SqlCockpitServiceControlElectron.ps1
```

Live settings-only change (no rebuild):

```powershell
Restart-Service SQLCockpitServiceHost
```

### Installer says "SQL Cockpit Service Control cannot be closed"

If NSIS shows:

- `SQL Cockpit Service Control cannot be closed. Please close it manually and click Retry to continue.`

close all running Service Control instances before retrying installer:

```powershell
# stop running app/tray processes
Get-Process -Name "SQL Cockpit Service Control","electron","node" -ErrorAction SilentlyContinue | Stop-Process -Force

# stop startup task from relaunching immediately
Stop-ScheduledTask -TaskName "SQLCockpitServiceTrayAtLogon" -ErrorAction SilentlyContinue

# optional: stop service host during installer update windows
Stop-Service -Name "SQLCockpitServiceHost" -ErrorAction SilentlyContinue
```

Then click `Retry` in the installer dialog.

If installer is still blocked, run the full reset script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\service\windows\Reset-SqlCockpitServiceControlDevEnvironment.ps1
```

Recommended dev-cycle installer launch (auto-clean before install):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\service\windows\Run-SqlCockpitSuiteInstaller.ps1
```

Optional explicit installer path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\service\windows\Run-SqlCockpitSuiteInstaller.ps1 `
  -InstallerPath "C:\Scripts\SQL Tables Sync\service\windows\publish\electron-control-YYYYMMDD-HHMMSS\SQL Cockpit Service Control Setup X.Y.Z.exe"
```

## Launch Desktop App From Service Host

The Windows SCM service host can now launch the SQL Cockpit desktop app as a managed component (`desktop-app`) using `Start-SqlCockpitDesktopPackaged.ps1`.

Notes:

- confirmed: the component is `disabled: false` and `autoStart: false` in the service settings templates so it appears in the Service Control UI but does not launch automatically.
- confirmed: the component launches a packaged desktop executable path (`-DesktopExecutablePath "C:\Program Files\SQL Cockpit\SQL Cockpit.exe"`), not `npm run electron`.
- confirmed: if `-DesktopExecutablePath` is omitted, the launcher falls back to the latest portable EXE under `webapp\publish\desktop-*`.
- confirmed: the component launches the desktop app in client mode (`-ManageComponents false`) with `-ServiceHostControlUrl http://127.0.0.1:8610/`.
- operational risk: if the SCM service runs under `LocalSystem`, the UI may not appear on the interactive desktop. For interactive launches, run the service under a user account or launch the desktop app directly via `Start-SqlCockpitDesktop.ps1`.

## Build The Docs

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\check_docs.ps1
```

`check_docs.ps1` regenerates config docs and runs `mkdocs build --strict`.

For an auto-rebuilding generated site without restarting the docs host, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\build_docs.ps1
```

Use `-Once` when you only want a single build:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\build_docs.ps1 -Once
```

## REST Route Trace

Use `Test-RestApiEndpoint.ps1` when REST and direct PowerShell behaviour differ. Trace files are written under `.\Logs\RestApiTrace`.

## Local Logs

| Log area | Location |
| --- | --- |
| Workspace and launcher logs | `.\Logs` |
| Browser-reported errors | `.\Logs\WebApp\client-errors-YYYY-MM-DD.jsonl` |
| Node route errors | `.\Logs\WebApp\server-errors-YYYY-MM-DD.jsonl` |
| Node process exceptions | `.\Logs\WebApp\process-errors-YYYY-MM-DD.jsonl` |
| REST probe traces | `.\Logs\RestApiTrace` |
| Object-search sync status | `object-search\data\object-search\sync-status.json` |

## Port Conflict Tracing And Force Cleanup (Windows)

Use this when desktop/service components fail with `Only one usage of each socket address...` or `EADDRINUSE`.

Trace listeners:

```powershell
Get-NetTCPConnection -LocalPort 8000,8001,8080,8090,8094,8610 -State Listen -ErrorAction SilentlyContinue |
  Select-Object LocalPort,OwningProcess,@{N='Name';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}
```

Force-kill listeners on known SQL Cockpit ports:

```powershell
$ports = 8000,8001,8080,8090,8094,8610
foreach ($p in $ports) {
  $pids = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($pid in $pids) {
    if ($pid -and $pid -gt 0) { taskkill /F /PID $pid }
  }
}
```

If processes immediately respawn, stop the Windows service host first:

```powershell
Get-Service -Name "SQLCockpitServiceHost" -ErrorAction SilentlyContinue | Stop-Service -Force
```

Verify ports are free:

```powershell
foreach ($p in 8000,8001,8080,8090,8094,8610) {
  $listeners = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
  if ($listeners) { "PORT $p STILL IN USE" } else { "PORT $p FREE" }
}
```

Operational note:

- confirmed: for desktop client mode, use port split `desktop 8000`, `docs 8001` to avoid self-conflict.

## Multi-Repo Orchestrator Workflow

For the split workspace model (`desktop/api/service-control/object-search`), use the parent repo as a thin orchestrator.

Manifest:

- `repos.manifest.json`

Bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-SqlCockpitWorkspace.Orchestrator.ps1 -CloneMissing -InstallDependencies -ProvisionServiceSettings
```

Fresh-start export from this monorepo into separate working trees:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\orchestrator\Export-SqlCockpitSplitRepos.ps1 -InitializeGit
```

Only update service settings repo roots (no clone/install):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\orchestrator\Set-SqlCockpitServiceSettingsRepoRoots.ps1 `
  -DesktopRepoRoot "C:\Repos\sql-cockpit\sql-cockpit-desktop" `
  -ApiRepoRoot "C:\Repos\sql-cockpit\sql-cockpit-api" `
  -ServiceRepoRoot "C:\Repos\sql-cockpit\sql-cockpit-service-control" `
  -ObjectSearchRepoRoot "C:\Repos\sql-cockpit\sql-cockpit-object-search"
```

## Full Uninstall And Clean Reinstall (Windows)

Yes, there are now repo scripts for this.

Machine uninstall + cleanup only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\orchestrator\Reset-SqlCockpitMachine.ps1 `
  -BasePath "C:\Scripts\SQL Tables Sync"
```

End-to-end clean install (uninstall -> rebuild all components -> launch suite installer):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\orchestrator\Invoke-SqlCockpitCleanInstall.ps1 `
  -BasePath "C:\Scripts\SQL Tables Sync"
```

Useful switches:

- `-SkipUninstall` (build/reinstall only)
- `-SkipBuild` (uninstall + reinstall latest already-built artifacts)
- `-SkipInstallerLaunch` (stop after builds)
- `-KeepSettings` (preserve `%ProgramData%\SqlCockpit\sql-cockpit-service.settings.json`)

Operational risk:

- `Reset-SqlCockpitMachine.ps1` removes installed SQL Cockpit apps, tray tasks, service host, and build artifacts.
- use `-KeepSettings` if you need to preserve local service configuration.
