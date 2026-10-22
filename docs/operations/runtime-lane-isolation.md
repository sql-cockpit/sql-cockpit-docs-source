# Runtime Lane Isolation

SQL Cockpit uses explicit `dev`, `test`, and `prod` lanes to keep development, internal testing, and production or beta cloud validation isolated from each other.

## Lane defaults

| Lane | Service Host | Agent service | Intended source |
| --- | --- | --- | --- |
| `dev` | `SQLCockpitServiceHost.Dev` | `SqlCockpit.Agent.Dev` | working repositories |
| `test` | `SQLCockpitServiceHost.Test` | `SqlCockpit.Agent.Test` | packaged release artifacts |
| `prod` | `SQLCockpitServiceHost.Prod` | `SqlCockpit.Agent.Prod` | promoted production artifacts |

Legacy unsuffixed services remain supported. New side-by-side installs should pass `-EnvironmentId`. The source ServiceManager installer publishes from its checkout; use it only for a reviewed development/install scenario. Test/prod must use promoted main artifacts, not an arbitrary working branch.

## Install examples

```powershell
.\sql-cockpit-os-services\windows\Install-SqlCockpitWindowsService.ps1 -EnvironmentId test
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

The API checks explicitly configured Agent environment identities against its lane during registration and heartbeat. The Agent keeps an empty identity as a legacy compatibility default; explicit lane configuration is required to enforce that comparison. Invitation-granted capabilities remain authoritative independently of lane identity.

The API environment route uses the existing service-status permission check and is blocked in Demo Mode. Host environment/doctor routes are separate local Host endpoints: keep loopback enforcement enabled and supply `X-SqlCockpit-Service-Key` when configured. They return metadata, not service keys; configured filesystem paths are still operational information.

## Service Control view

The legacy companion Control app in ServiceManager shows an **Environment Services** table with separate `dev`, `test`, and `prod` rows. Each lane is read from `%ProgramData%\SqlCockpit\Environments\<lane>\sql-cockpit-service.settings.json` and controlled through that lane's service name and control API URL.

- Service actions affect only the selected lane.
- Component actions call only the selected lane's Service Host control API.
- Missing lanes show as `Not Installed`.
- The original **Managed Components** table remains scoped to the active settings file.

The current desktop product is the separate `sql-cockpit-service-control` repository. Its global environment settings and source launcher take precedence over this legacy companion view. Do not replace it with the old companion while consolidating branches.

Explicit missing settings/lane requests fail closed. Opening scoped lane settings preserves ports, disabled components and runtime profile. Existing `SqlCockpit/<lane>` directories are not moved automatically: back up and reconcile their data before changing paths.

## Safe tester workflow

1. Build release artifacts from a known commit.
2. Install the `test` Service Host and `test` Agent.
3. Confirm Service Control shows `Environment: TEST`.
4. Confirm the **Environment Services** table shows the `test` lane separately from `dev` and `prod`.
5. Verify `GET /api/runtime/environment` returns the expected lane, release, and build SHA.
6. Pair the local Agent to the local test API or Azure test tenant only.
7. Run SQL Bridge, SQL Editor, object search, and hosted cloud checks through the Agent boundary.
8. Promote the same accepted artifact to `prod`.

## Config reference

| Name | Storage | Valid values | Default | Runtime usage | Risk | Safe change |
| --- | --- | --- | --- | --- | --- | --- |
| `environmentId` / `SQL_COCKPIT_ENVIRONMENT` / `SQL_COCKPIT_ENVIRONMENT_ID` | Host JSON, Agent JSON, API env | `dev`, `test`, `prod`; legacy Agent may omit identity | Host/API: `prod`; Agent: empty for legacy compatibility | Lane identity and Agent pairing guard | Wrong lane can test against the wrong tenant | Stop services, update, restart, verify runtime endpoint |
| `channelName` / `SQL_COCKPIT_CHANNEL_NAME` | JSON/env | short text | lane id | Display and heartbeat metadata | Mislabeling confuses testers | Update with services stopped |
| `releaseVersion` / `SQL_COCKPIT_RELEASE_VERSION` | JSON/env | release label | empty | Release display | Missing version weakens reports | Set during packaging |
| `buildSha` / `SQL_COCKPIT_BUILD_SHA` | JSON/env | commit SHA | empty | Reproducible build identity | Missing SHA weakens reports | Set during packaging |
| `dataRoot` | Service Host JSON | absolute path | `%ProgramData%\SqlCockpit\Environments\<lane>\data` | Lane-local data | Shared data can contaminate tests | Keep unique per lane |
| `logsRoot` | Service Host JSON | absolute path | `%ProgramData%\SqlCockpit\Environments\<lane>\Logs` | Lane-local logs | Shared logs obscure incidents | Keep unique per lane |

The Host passes the data root to child processes as `SQL_COCKPIT_SQLITE_STATE_ROOT` and sets the local auth file below that root. Hosted `SQL_COCKPIT_STATE_PROVIDER` selection remains inherited; local paths do not authorize hosted SQLite fallback. Release and commit values are metadata, not artifact promotion.

Confidence: contracts checked against merged API/Agent code and ServiceManager PR #3. Source tests and isolated diagnostics passed there; existing-state migration and a real SCM installation remain unverified. No installed lane is changed by this documentation PR.
