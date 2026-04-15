# Desktop Service Manager

Use this page to train operators on the SQL Cockpit `Service Manager` dashboard route (`/service-manager`).

This guide focuses on day-to-day GUI operation. For deep Windows SCM internals, use:

- [Desktop Service Manager (operations)](../operations/service-manager.md)
- [Windows SCM Service Host](../operations/windows-service-host.md)

## What it controls

The Desktop Service Manager controls background runtime components used by SQL Cockpit:

- Docs server
- Notifications server
- Object search service

In SCM-backed deployments, the page can proxy control through the Windows service host API.
In local desktop mode, it can control the embedded runtime supervisor.

## Startup quickstart by profile

Use one profile at a time:

1. Dev profile (desktop owns runtime):
```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.Dev.ps1" -ConfigServer "<server>" -ConfigDatabase "<db>" -ConfigIntegratedSecurity
```
2. Prod client profile (SCM owns runtime):
```powershell
powershell -ExecutionPolicy Bypass -File ".\Start-SqlCockpitDesktop.ProdClient.ps1" -ConfigServer "<server>" -ConfigDatabase "<db>" -ConfigIntegratedSecurity -ServiceHostControlUrl "http://127.0.0.1:8610"
```

Do not mix ownership (`ManageComponents=true` and `ServiceHostControlUrl` together).

For detailed launch and validation instructions, see [Runtime Modes: Development vs Production](runtime-modes.md).

## Where to find it

In SQL Cockpit left navigation:

1. Open the `Settings` section.
2. Select `Service Manager`.

## UI sections

The page has two primary panels:

1. `Desktop Background Services`: component table and action buttons.
2. `Supervisor Settings`: current runtime policy values (auto start, restart behavior, polling).

The `Service Manager Feed` box shows recent action outcomes and error text.

## Button reference

Top-level actions:

- `Refresh` (refresh icon): reload current runtime component state.
- `Start all` (play icon): start all managed components.
- `Restart all` (restart icon): restart all managed components.
- `Stop all` (stop icon): stop all managed components.

Per-component actions:

- `Start` (play icon): start one component.
- `Restart` (restart icon): restart one component.
- `Stop` (stop icon): stop one component.

## Reading component state

Each row displays:

- `Status`: `Running`, `Stopped`, or transitional (`Starting`, `Stopping`)
- `Health`: `healthy`, `unhealthy`, or `unknown`
- `PID`: process id for the running child process
- `Last Start`: last known startup timestamp

Interpretation guidance:

- `Running` + `healthy`: normal
- `Running` + `unhealthy`: process is up but failing health checks
- `Stopped` + `healthy`: stale state; click `Refresh`
- `unknown` health: endpoint unavailable or health probe not configured

## Standard operating procedure

Use this order during normal checks:

1. Open `Settings` -> `Service Manager`.
2. Click `Refresh`.
3. Confirm all required services are `Running`.
4. Confirm health is `healthy`.
5. If one service is unhealthy, restart that single service.
6. Re-check after the configured restart delay and health poll interval.

## Incident triage quick playbook

If one component fails repeatedly:

1. Capture the exact message from `Service Manager Feed`.
2. Restart only the affected component.
3. If failure repeats, validate its script/config path in service settings.
4. Check local logs referenced by the service host/runtime config.
5. Escalate with timestamp, component id, and last error text.

If all components fail at once:

1. Verify service host/API reachability (`/health`) if SCM-backed.
2. Confirm control URL and API key alignment between desktop and service settings.
3. Restart all services once.
4. If still failing, perform host-level restart per operations runbook.

## Training checklist

Use this as a practical onboarding exercise:

1. Navigate to `Service Manager` from `Settings`.
2. Identify each managed component by name and status.
3. Run `Refresh` and explain any changes.
4. Restart one component and confirm state transitions.
5. Locate and read the `Service Manager Feed` output.
6. Explain when to use single-service restart vs `Restart all`.

## Safe-use guardrails

- Prefer per-component restart first to reduce collateral interruption.
- Avoid repeated rapid restart loops; wait for one full health cycle.
- Do not change service settings and runtime ownership model simultaneously during incidents.
- Record actions taken and timestamps for handover and audit.

## Related references

- [Dashboard Guide](dashboard-guide.md)
- [Operational Safety](operational-safety.md)
- [Desktop Service Manager (operations)](../operations/service-manager.md)
- [Windows SCM Service Host](../operations/windows-service-host.md)
