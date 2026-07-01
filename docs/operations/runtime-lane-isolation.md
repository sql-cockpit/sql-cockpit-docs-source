# Runtime Lane Isolation

SQL Cockpit uses explicit `dev`, `test`, and `prod` lanes to keep development, internal testing, and production or beta cloud validation isolated from each other.

## Lane defaults

| Lane | Service Host | Agent service | Intended source |
| --- | --- | --- | --- |
| `dev` | `SQLCockpitServiceHost.Dev` | `SqlCockpit.Agent.Dev` | working repositories |
| `test` | `SQLCockpitServiceHost.Test` | `SqlCockpit.Agent.Test` | packaged release artifacts |
| `prod` | `SQLCockpitServiceHost.Prod` | `SqlCockpit.Agent.Prod` | promoted production artifacts |

Legacy unsuffixed production services remain supported. New side-by-side installs should pass `-EnvironmentId`.

## Install examples

```powershell
.\sql-cockpit-os-services\windows\Install-SqlCockpitWindowsService.ps1 -EnvironmentId test -StartAfterInstall
```

```powershell
.\sql-cockpit-agent\windows\Install-SqlCockpitAgent.ps1 `
  -EnvironmentId test `
  -CloudBaseUrl "https://sql-cockpit-test.example.com" `
  -InviteCode "<tenant invite code>" `
  -AllowedSqlServers @("localhost","YOUR-SQL-SERVER")
```

## Runtime identity

- API: `GET /api/runtime/environment`
- Service Host: `GET /api/runtime/environment` and `GET /api/runtime/doctor`
- Agent registration and heartbeat: `environmentId`, `channelName`, `releaseVersion`, and `buildSha`

The tenant API rejects cross-lane Agent registration and heartbeat. A `test` agent cannot silently pair with a `prod` tenant.

## Safe tester workflow

1. Build release artifacts from a known commit.
2. Install the `test` Service Host and `test` Agent.
3. Confirm Service Control shows `Environment: TEST`.
4. Verify `GET /api/runtime/environment` returns the expected lane, release, and build SHA.
5. Pair the local Agent to the local test API or Azure test tenant only.
6. Run SQL Bridge, SQL Editor, object search, and hosted cloud checks through the Agent boundary.
7. Promote the same accepted artifact to `prod`.

## Config reference

| Name | Storage | Valid values | Default | Runtime usage | Risk | Safe change |
| --- | --- | --- | --- | --- | --- | --- |
| `environmentId` / `SQL_COCKPIT_ENVIRONMENT` | Service Host JSON, Agent JSON, API env | `dev`, `test`, `prod` | `prod` | Lane identity and Agent pairing guard | Wrong lane can test against the wrong tenant | Stop services, update, restart, verify runtime endpoint |
| `channelName` / `SQL_COCKPIT_CHANNEL_NAME` | JSON/env | short text | lane id | Display and heartbeat metadata | Mislabeling confuses testers | Update with services stopped |
| `releaseVersion` / `SQL_COCKPIT_RELEASE_VERSION` | JSON/env | release label | empty | Release display | Missing version weakens reports | Set during packaging |
| `buildSha` / `SQL_COCKPIT_BUILD_SHA` | JSON/env | commit SHA | empty | Reproducible build identity | Missing SHA weakens reports | Set during packaging |
| `dataRoot` | Service Host JSON | absolute path | `%ProgramData%\SqlCockpit\<lane>\data` | Lane-local data | Shared data can contaminate tests | Keep unique per lane |
| `logsRoot` | Service Host JSON | absolute path | `%ProgramData%\SqlCockpit\<lane>\Logs` | Lane-local logs | Shared logs obscure incidents | Keep unique per lane |

Confidence: confirmed for Service Host, Agent installer/runtime, API runtime metadata, OpenAPI entry, and Agent store schema. Route-level SaaS Agent registration wiring depends on the active API tree containing the restored agent routes.
