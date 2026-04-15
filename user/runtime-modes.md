# Runtime Modes: Development vs Production

This guide explains exactly how to launch SQL Cockpit in:

- Development mode (`dev`)
- Production client mode (`prod`, with Windows SCM service host ownership)

Use this page when you need repeatable startup steps.

## Choose the correct mode

Use `dev` when:

- you are changing docs, web UI/API, notifications, or object-search code
- you need live-reload/watch behavior
- you want desktop to own runtime components locally

Use `prod` when:

- the Windows service host is running `web-api`, `docs`, `notifications`, and `object-search`
- desktop should act as a client and control SCM-hosted components
- you need production-like ownership boundaries

## Ownership contract (must match)

| Mode | Runtime owner | Required launch contract |
| --- | --- | --- |
| `dev` | Desktop embedded runtime manager | `ManageComponents=true`, no `ServiceHostControlUrl` |
| `prod` | Windows SCM service host | `ManageComponents=false`, `ServiceHostControlUrl` set, `ExternalApiOnly=true` |

SQL Cockpit now enforces this at startup and fails fast on invalid combinations.

## Development mode launch

From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.Dev.ps1" `
  -ConfigServer "<server>" `
  -ConfigDatabase "<database>" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate
```

Expected behavior in `dev`:

- docs run with MkDocs live-reload
- web API runs in dev mode
- notifications run with Node watch
- object-search runs with `dotnet watch run`
- Service Manager controls locally-owned runtime components

## Production client mode launch

Before launching desktop, ensure the SCM host is installed and running:

```powershell
powershell -ExecutionPolicy Bypass -File ".\service\windows\Install-SqlCockpitWindowsService.ps1" -SettingsProfile prod -StartAfterInstall
```

Launch desktop as SCM client:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.ProdClient.ps1" `
  -ConfigServer "<server>" `
  -ConfigDatabase "<database>" `
  -ConfigSchema "Sync" `
  -ConfigIntegratedSecurity `
  -TrustServerCertificate `
  -ServiceHostControlUrl "http://127.0.0.1:8610/"
```

If service `apiKey` is set in `%ProgramData%\SqlCockpit\sql-cockpit-service.settings.json`, include:

```powershell
-ServiceHostApiKey "<same-key>"
```

Expected behavior in `prod`:

- desktop does not own side services
- desktop does not spawn embedded API (client-only bootstrap)
- runtime actions in Service Manager proxy to SCM service host control API
- component health/status reflects service-host state

## Validation checks after launch

Run these checks for both modes:

1. Open dashboard.
2. Open `Settings` -> `Service Manager`.
3. Click `Refresh`.
4. Confirm required components show `Running`.
5. Confirm health is `healthy`.

Additional checks for `prod`:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8610/health
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8610/api/runtime/components
```

## Common failures and fixes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Startup fails with ownership/profile error | mixed `ManageComponents` + `ServiceHostControlUrl` contract | use the mode-specific wrapper script and retry |
| `401 Unauthorized` from Service Manager in prod mode | API key mismatch | set same key in service settings and launch with `-ServiceHostApiKey` |
| Service Manager cannot refresh in prod mode | wrong/offline service host URL | test `/health` on control URL and correct the launch argument |
| Dev mode not auto-reloading | wrong launcher used | use `Start-SqlCockpitDesktop.Dev.ps1` |

## Recommended daily commands

Development:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.Dev.ps1" -ConfigServer "<server>" -ConfigDatabase "<database>" -ConfigIntegratedSecurity
```

Production client:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.ProdClient.ps1" -ConfigServer "<server>" -ConfigDatabase "<database>" -ConfigIntegratedSecurity -ServiceHostControlUrl "http://127.0.0.1:8610/"
```

## Related pages

- [First Run](first-run.md)
- [Desktop Service Manager](desktop-service-manager.md)
- [Desktop Service Manager (operations)](../operations/service-manager.md)
- [Windows SCM Service Host](../operations/windows-service-host.md)
- [Windows Service Control (Electron)](../operations/windows-service-control-electron.md)
