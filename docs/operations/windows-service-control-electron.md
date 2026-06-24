# Windows Service Control (Electron)

This app is a separate Windows desktop companion for controlling the SQL Cockpit SCM host.

It provides:

- tray icon access
- dedicated service-control UI
- in-app update checks and install prompts using `electron-updater`
- suite repair entrypoint (`Run Repair (UAC)`) for desktop/service/task reconciliation

```mermaid
flowchart LR
    A[SQL Cockpit Suite Setup.exe] --> B[Install Desktop App]
    A --> C[Provision SQLCockpitServiceHost]
    A --> D[Register tray startup task]
    C --> E[Service Host Control API :8610]
    F[Service Control Electron] --> E
    H[Desktop App Auto-Updater] --> I[GitHub Releases]
    F --> J[Service Control Auto-Updater]
    J --> I
```

## Capabilities

The Electron app supports:

- header environment badge (`Environment: Development Build` or `Environment: Production Build`)
- runtime profile suffix in the badge when available (for example `Runtime: prod`)
- Windows service status (`SQLCockpitServiceHost`)
- service start/stop actions
- component snapshot list (`id`, `display`, status, health, PID, restart count, last start, last error)
- per-component `Start`, `Restart`, `Stop`
- bulk `Start All`, `Restart All`, `Stop All`
- auto-refresh every 15 seconds
- quick action button to open Docs in the default browser (uses docs component URL from service settings, falls back to `http://127.0.0.1:8000/`)
- health-first component adoption: if a configured `healthUrl` or `alternateHealthUrls` endpoint answers successfully, Service Control shows the component as running even when the process was started by the local-dev stack instead of `SQLCockpitServiceHost`
- automatic managed API bootstrap on app start:
  - reconciles `web-api` service settings contract (`--listenPrefix http://127.0.0.1:8000/`, `autoStart=true`, `workingDirectory={ApiRepoRoot}`)
  - ensures split-era repo root keys exist in settings (`desktopRepoRoot`, `apiRepoRoot`, `serviceRepoRoot`, `objectSearchRepoRoot`)
  - enforces `--serviceHostControlUrl` for `web-api` in prod mode so API startup contract is valid
  - attempts to start `SQLCockpitServiceHost` and `web-api` if they are not running
- in suite-managed prod mode, desktop launch is client-only (`-ExternalApiOnly true`) and connects to SCM-managed `web-api` on `http://127.0.0.1:8000/`
- desktop launch preflight that checks the configured desktop listen-prefix port before launch and shows an immediate warning if the port is already in use (warning-only; launch continues)
- `Run Repair (UAC)` action that re-runs suite provisioning with path migration and health validation
- update actions:
  - `Check For Updates`
  - `Install Downloaded Update`
- the legacy `desktop-app` managed component is no longer provisioned; Service Control manages the Windows service host, runtime services, updates, and SQL Cockpit Agent only
- SQL Cockpit Agent live output viewer:
  - connects to the agent's local named pipe, `\\.\pipe\SqlCockpit.Agent.LogStream` by default
  - shows recent in-memory agent log events and follows new events
  - does not write files unless an operator clicks `Log To File` and chooses a capture path

## SQL Cockpit Agent live output

Use the `Live Logs` button on the `sql-cockpit-agent` managed component when you need to see what the agent is doing without enabling persistent disk logging.

Default behaviour:

- agent-side setting: `Agent:LiveLogEnabled=true`
- agent-side pipe: `Agent:LiveLogPipeName=SqlCockpit.Agent.LogStream`
- agent-side memory replay: `Agent:LiveLogBufferSize=500`
- Service Control reads the installed agent `appsettings.json` under `agentInstallDirectory` when it needs a non-default pipe name
- no log files are created by the agent or Service Control by default

File capture is operator-driven:

1. Click `Live Logs` on the `sql-cockpit-agent` row.
2. Confirm live output appears in the modal.
3. Click `Log To File`.
4. Choose a temporary `.ndjson` or `.log` file.
5. Reproduce the issue or wait for the next heartbeat/job event.
6. Click `Stop File Log` before sharing or deleting the capture.

Operational risk: captured files can contain exception text, server names, profile identifiers, and local path details. Do not store long-running captures by default, and delete temporary captures after diagnosis unless your incident process requires retention.

## Files

- app directory: `service/windows/SqlCockpit.ServiceControl.Electron`
- launcher: `service/windows/Start-SqlCockpitServiceControlElectron.ps1`
- packager: `service/windows/Publish-SqlCockpitServiceControlElectron.ps1`
- logon startup installer (canonical): `service/windows/Install-SqlCockpitServiceTrayStartup.ps1`
- compatibility installer alias: `service/windows/Install-SqlCockpitServiceControlElectronStartup.ps1`

## Development run

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Start-SqlCockpitServiceControlElectron.ps1"
```

With explicit settings path:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Start-SqlCockpitServiceControlElectron.ps1" `
  -SettingsPath "E:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json"
```

Disable startup API auto-bootstrap for troubleshooting:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Start-SqlCockpitServiceControlElectron.ps1" `
  -AdditionalArgs "--autoStartApi=false"
```

Run launcher with elevation:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Start-SqlCockpitServiceControlElectron.ps1" `
  -SettingsPath "E:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json" `
  -RunAsAdministrator
```

For clean installer retest cycles during development:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Reset-SqlCockpitServiceControlDevEnvironment.ps1"
```

## Build packages (Suite Installer)

Build NSIS installer + portable:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Publish-SqlCockpitServiceControlElectron.ps1"
```

Build portable only:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Publish-SqlCockpitServiceControlElectron.ps1" -PortableOnly
```

Output path:

- timestamped folder per build, for example `service/windows/publish/electron-control-20260414-203000/`

This avoids stale file-lock failures in `win-unpacked` when prior build artifacts are still in use.

Before building, the publisher now stages the desktop installer into `service/windows/DesktopBundle/SQL Cockpit setup.exe`.

If auto-discovery fails, pass an explicit desktop setup path:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Publish-SqlCockpitServiceControlElectron.ps1" `
  -DesktopSetupPath "C:\path\to\SQL Cockpit setup.exe"
```

## Installer provisioning behavior (Single Suite Flow)

The NSIS installer is now the canonical SQL Cockpit Suite installer and performs post-install provisioning automatically:

1. installs SQL Cockpit Desktop app from bundled setup payload
2. installs or updates `SQLCockpitServiceHost` (Windows SCM)
3. migrates settings and removes the legacy `desktop-app` managed component if it exists
4. starts service host and validates `http://127.0.0.1:8610/health`
5. registers/starts `SQLCockpitServiceTrayAtLogon`

Current implementation details:

- installer hook file: `service/windows/SqlCockpit.ServiceControl.Electron/build/installer.nsh`
- post-install script: `service/windows/SqlCockpit.ServiceControl.Electron/build/setup-scripts/post-install.ps1`
- post-uninstall script: `service/windows/SqlCockpit.ServiceControl.Electron/build/setup-scripts/post-uninstall.ps1`
- suite repair script: `service/windows/Repair-SqlCockpitSuite.ps1`
- suite install wrapper: `service/windows/Install-SqlCockpitSuite.ps1`

Prerequisites:

- run installer elevated (Administrator)
- `dotnet` SDK must be available on the machine, because suite provisioning runs `dotnet publish` from bundled service-host source

Uninstall policy:

- service host and tray task are removed by suite uninstall.
- desktop app is preserved by default and can be removed via its own uninstaller.

## In-app updates (GitHub releases)

The app uses `electron-updater` with GitHub provider configured in:

- `service/windows/SqlCockpit.ServiceControl.Electron/package.json`

Current publish target:

- owner: `jjmpsp`
- repo: `sql-cockpit-servicemanager`
- release type: `release`

### How updates work

1. publish a newer app version to GitHub releases
2. installed app checks for updates on startup (packaged mode)
3. app downloads update in background
4. UI enables `Install Downloaded Update`
5. app restarts and applies update

### Release checklist

1. increment app version in `service/windows/SqlCockpit.ServiceControl.Electron/package.json`
2. commit and push version change
3. create and push a semver tag (example: `v1.0.1`)
4. GitHub Actions workflow `service/.github/workflows/release-electron.yml` builds and publishes installer assets to GitHub Releases
5. verify client receives update prompt

Release runbook:

- [Windows Service Control Repo Release Runbook](windows-service-control-release.md)

## Auto-start at user logon

After building the app:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Install-SqlCockpitServiceTrayStartup.ps1" `
  -RunImmediately
```

Optional:

- `-TaskName "<custom-name>"`
- `-ExecutablePath "<full path to SQL Cockpit Service Control.exe>"`
- `-UseHighestPrivileges`

## Run as Administrator by default

Recommended approach:

- keep normal app startup, and let `Start Service`/`Stop Service` trigger UAC on demand (current behavior)
- this minimizes always-elevated app runtime while still allowing service control actions

Alternative approaches:

1. Start from a scheduled task with highest privileges:
- register task with `-UseHighestPrivileges`
- launch app via that task (or at logon)

2. Force app elevation at process startup (packaged build):
- set `build.win.requestedExecutionLevel` in `service/windows/SqlCockpit.ServiceControl.Electron/package.json` to `highestAvailable` or `requireAdministrator`
- caveat: app will request elevation every launch; this can increase friction and can complicate updater/install behavior in some environments

Operator instruction for manual elevated launch:

1. close the app
2. right-click `SQL Cockpit Service Control`
3. select `Run as administrator`

## Settings and API auth

The app reads `E:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json` by default. Operators can override this with `--settings` or the `SQL_COCKPIT_SERVICE_SETTINGS_PATH` environment variable.

Used fields:

- `serviceName`
- `agentServiceName`
- `agentRepoRoot`
- `agentInstallDirectory`
- `listenPrefix`
- `apiKey`
- per-component `healthUrl` and optional `alternateHealthUrls`; `alternateHealthUrls` is used for local-dev/prodlike overlap, for example recognizing `http://127.0.0.1:8080/health` while the service-host command remains configured for `http://127.0.0.1:8000/`

If `apiKey` is present, requests include header:

- `X-SqlCockpit-Service-Key`

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| UI cannot load runtime components | service host not running or bad control URL | validate `Get-Service SQLCockpitServiceHost` and `Invoke-WebRequest http://127.0.0.1:8610/health` |
| local-dev stack is healthy but components show `Stopped` | service host is using stale owned-process state instead of adopting externally started health endpoints | verify `alternateHealthUrls` includes the local-dev endpoint, for example `http://127.0.0.1:8080/health` for `web-api`, then restart `SQLCockpitServiceHost` |
| actions return `401` | API key mismatch | align `apiKey` between service settings and client |
| update checks fail in dev | app not packaged | expected; auto-updates are for packaged builds/releases |
| service start/stop fails | UAC was canceled or elevation failed | retry action and accept the UAC prompt; if it still fails, run the app elevated and verify local policy allows service control |
| Agent shows `Not Installed` | `SqlCockpit.Agent` has not been created on this machine | click `Install` on the `sql-cockpit-agent` managed row, choose local/on-prem/cloud, enter the SQL Cockpit URL, open `/admin/agent-binding` from the wizard, create/copy the binding code, approve UAC, then refresh |
| Agent install fails with missing installer | `agentRepoRoot` does not point at the `sql-cockpit-agent` repository | update `E:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json`, then verify `agentRepoRoot\windows\Install-SqlCockpitAgent.ps1` exists |
| Agent install succeeds but pairing fails | invite code is expired/claimed or SQL Cockpit URL is wrong | create a fresh invite, confirm the URL reaches the tenant from the local machine, rerun Install/Repair Agent |
| Integrated-auth SQL profile fails as `DOMAIN\MACHINE$` | `SqlCockpit.Agent` is running as `LocalSystem`, so SQL Server sees the machine account | grant SQL access to the machine account or change the agent to a domain service account/gMSA; see [SQL Cockpit Agent Identity And Windows Authentication](sql-cockpit-agent-identity.md) |
| start/stop shows `...canceled at UAC prompt` | user dismissed UAC prompt | click action again and approve UAC, or start/stop service from elevated PowerShell |
| legacy `desktop-app` row appears in Managed Components | old service settings still include the retired desktop component | remove the `desktop-app` entry from `E:\ProgramData\SqlCockpit\sql-cockpit-service.settings.json`, restart `SQLCockpitServiceHost`, then refresh Service Control |
| suite install fails with missing desktop setup | desktop setup artifact was not bundled before build | run `Prepare-SqlCockpitSuiteDesktopBundle.ps1` (or pass `-DesktopSetupPath`) then rebuild suite installer |
| installer says app cannot be closed | tray/app process still running and locking install files | stop `SQL Cockpit Service Control`/`electron` processes, stop `SQLCockpitServiceTrayAtLogon` task, then click `Retry` |
| suite repair fails with `MSB3027/MSB3021` file lock on `SqlCockpit.ServiceHost.Windows.dll` | service host process still holds publish output | stop/kill `SQLCockpitServiceHost`, then rerun `Repair-SqlCockpitSuite.ps1` (optionally with `-SkipDesktopInstall` for faster retries) |

For dev cycles, use the wrapper script that pre-stops lock holders before launching installer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\service\windows\Run-SqlCockpitSuiteInstaller.ps1"
```

UI diagnostics behavior (current implementation):

- `Version`, `Settings`, and `Control API` now render from metadata even when runtime status calls fail.
- if settings cannot be read, the status bar now includes a `settings:` warning with the exact error.
- if the control API is unreachable, the managed-components table now shows `No managed components available` with the runtime error text.
- if the Windows service query fails, the status bar now includes a `service:` warning while keeping the rest of the UI responsive.
