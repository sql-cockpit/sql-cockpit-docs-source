# Runbooks

## Onboard a new sync target

1. Create or review the `Sync.TableConfig` row.
   Use `New-SyncTableConfig.ps1` for the interactive path documented in [Create Sync Jobs With The CLI](create-sync-jobs-with-cli.md).
2. Confirm source and destination connectivity and permissions.
3. Decide whether the first safe run should be `FullRefresh` or `Incremental`.
4. Set `KeyColumnsCsv` and optional watermark settings.
5. Decide whether `AutoCreateDestinationTable` is allowed.
6. Keep `PreSyncSql` and `PostSyncSql` empty unless there is a reviewed need.
7. Run one manual sync with logging enabled.
8. Review `Sync.RunLog`, `Sync.RunActionLog`, and destination row counts.

## Set up a new workstation safely

1. Start the workspace on loopback.
2. Open the dashboard.
3. Complete `/setup` to create the first local administrator.
4. Sign in and open `Preferences`.
5. Confirm the local account details and change the password if the bootstrap password was temporary.
6. Save one low-risk instance profile and one low-risk connection profile.
7. Confirm `Fleet` or `Inspector` can read `Sync.TableConfig`.

## Reset local app auth safely

Use this only when the operator accepts losing workstation-local users, sessions, saved profiles, and user preferences.

1. Stop SQL Cockpit.
2. Back up `data/sql-cockpit/sql-cockpit-local.sqlite`.
3. Remove the SQLite file.
4. Restart the workspace.
5. Complete `/setup` again.
6. Recreate or revalidate saved profiles before running write workflows.

## Consolidate lane SQLite state

Local lanes use one SQLite app-state database:

`E:\ProgramData\SqlCockpit\<lane>\data\sql-cockpit\sql-cockpit-local.sqlite`

Older installs may also contain legacy files such as:

- `data\sql-cockpit\saas-agent-control.sqlite`
- `data\query-analyser\query-analyser.db`
- `data\sql-editor\sql-query-editor.db`
- `data\query-audit\query-audit.db`
- `data\sql-cockpit\rbac-auth.sqlite`

Do not delete those files until their rows have been copied into
`sql-cockpit-local.sqlite` and the lane has restarted cleanly.

From `E:\Scripts\SQL Tables Sync`, run the migration with the lane's actual
paths:

```powershell
node .\scripts\runtime\migrate-sqlite-lane-state.js `
  --target "E:\ProgramData\SqlCockpit\test\data\sql-cockpit\sql-cockpit-local.sqlite" `
  --agentControl "E:\ProgramData\SqlCockpit\test\data\sql-cockpit\saas-agent-control.sqlite" `
  --queryAnalyser "E:\ProgramData\SqlCockpit\test\data\query-analyser\query-analyser.db" `
  --sqlQueryEditor "E:\ProgramData\SqlCockpit\test\data\sql-editor\sql-query-editor.db" `
  --queryAudit "E:\ProgramData\SqlCockpit\test\data\query-audit\query-audit.db" `
  --rbacAuth "E:\ProgramData\SqlCockpit\test\data\sql-cockpit\rbac-auth.sqlite"
```

Safe validation:

1. Restart the lane web API.
2. Confirm `GET /health` returns `200`.
3. Sign in and check saved users/workspaces.
4. Confirm SQL Editor tabs/history, Query Analyser history, Query Audit, and
   Agent Binding still show expected data.
5. Archive the legacy files only after the lane has run successfully from
   `sql-cockpit-local.sqlite`.

## Reset a forgotten local admin password

Use this break-glass procedure when a local SQL Cockpit administrator has forgotten their password but the lane's local auth SQLite database is still available. This does not reset SQL Server logins, saved profile secrets, LDAP, or Azure AD accounts.

Prerequisites:

- Run the commands on the host that owns the SQL Cockpit lane.
- Use an elevated or service-account shell only if that is required to read the lane data directory.
- Back up the lane SQLite file before changing it.
- Pick a temporary password that meets the local policy: at least 12 characters with upper-case, lower-case, and numeric characters.

Common lane auth-store paths:

| Lane | Auth store path |
| --- | --- |
| Local development checkout | `E:\Scripts\SQL Tables Sync\sql-cockpit-api\data\sql-cockpit\sql-cockpit-local.sqlite` |
| Development service lane | `E:\ProgramData\SqlCockpit\dev\data\sql-cockpit\sql-cockpit-local.sqlite` |
| Test service lane | `E:\ProgramData\SqlCockpit\test\data\sql-cockpit\sql-cockpit-local.sqlite` |
| Production service lane | `E:\ProgramData\SqlCockpit\prod\data\sql-cockpit\sql-cockpit-local.sqlite` |

If the lane was started with a custom `--configStorePath` or `SQL_COCKPIT_CONFIG_STORE_PATH`, use that same SQLite file unless `SQL_COCKPIT_AUTH_STORE_PATH` explicitly points somewhere else.

From `E:\Scripts\SQL Tables Sync\sql-cockpit-api`, run:

```powershell
$authStorePath = 'E:\ProgramData\SqlCockpit\dev\data\sql-cockpit\sql-cockpit-local.sqlite'
$adminUsername = 'admin'
$newPassword = Read-Host -AsSecureString 'New temporary password'
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPassword)
)

$env:SQL_COCKPIT_AUTH_STORE_PATH = $authStorePath
$env:SQL_COCKPIT_NEW_ADMIN_PASSWORD = $plainPassword
$env:SQL_COCKPIT_ADMIN_USERNAME = $adminUsername

@'
const { getAuthStore } = require('./lib/local-auth');

(async () => {
  const store = getAuthStore(process.cwd());
  const users = store.listUsers();
  const admin = users.find((user) =>
    String(user.username || '').toLowerCase() === String(process.env.SQL_COCKPIT_ADMIN_USERNAME || '').toLowerCase()
  );
  if (!admin) throw new Error('Local admin user was not found.');
  if (!admin.isLocalAdmin) throw new Error('Selected user is not a local administrator.');

  await store.adminResetLocalPassword({
    actorUserId: admin.id,
    targetUserId: admin.id,
    newPassword: process.env.SQL_COCKPIT_NEW_ADMIN_PASSWORD,
    requestId: 'manual-local-admin-password-reset'
  });

  console.log(JSON.stringify({ ok: true, username: admin.username }));
})().catch((error) => {
  console.error(error?.message || String(error));
  process.exit(1);
});
'@ | node -

Remove-Item Env:\SQL_COCKPIT_NEW_ADMIN_PASSWORD -ErrorAction SilentlyContinue
Remove-Item Env:\SQL_COCKPIT_ADMIN_USERNAME -ErrorAction SilentlyContinue
Remove-Item Env:\SQL_COCKPIT_AUTH_STORE_PATH -ErrorAction SilentlyContinue
```

If repeated failed sign-ins have locked the account, clear only failed local login events for that principal:

```powershell
$authStorePath = 'E:\ProgramData\SqlCockpit\dev\data\sql-cockpit\sql-cockpit-local.sqlite'
$adminUsername = 'admin'

$env:SQL_COCKPIT_AUTH_STORE_PATH = $authStorePath
$env:SQL_COCKPIT_ADMIN_USERNAME = $adminUsername

@'
const Database = require('better-sqlite3');
const db = new Database(process.env.SQL_COCKPIT_AUTH_STORE_PATH);
const username = String(process.env.SQL_COCKPIT_ADMIN_USERNAME || '').trim();
const user = db.prepare('SELECT id, username FROM users WHERE lower(username) = lower(?)').get(username);
if (!user) throw new Error('Local admin user was not found.');

const result = db.prepare(`
  DELETE FROM login_events
  WHERE provider_type = 'local'
    AND lower(principal) = lower(?)
    AND success = 0
`).run(username);

console.log(JSON.stringify({ ok: true, username: user.username, deletedFailedEvents: result.changes }));
db.close();
'@ | node -

Remove-Item Env:\SQL_COCKPIT_ADMIN_USERNAME -ErrorAction SilentlyContinue
Remove-Item Env:\SQL_COCKPIT_AUTH_STORE_PATH -ErrorAction SilentlyContinue
```

Safe validation:

1. Start or confirm the target lane is healthy, for example `GET http://127.0.0.1:8280/health` for the development lane.
2. Sign in through that lane's login page with the temporary password.
3. Change the password again from the user account page if the temporary value was shared through an incident channel.
4. Review `/admin/audit` or `login_events` for the reset window and keep the backup until the admin confirms access.

Operational risk is high: this is direct local-auth database maintenance. Use it only from the lane host, protect the temporary password, and do not delete successful login events or unrelated users.

## Change a flag safely

1. Export the current `Sync.TableConfig` row.
2. Record the reason for change and rollback plan.
3. Change one field at a time.
   For new rows, prefer using the CLI so the initial insert follows the current runtime validation rules.
4. Run one manual execution if the field is medium or high risk.
5. Validate logs, state, and destination behaviour.

## Tune `BatchSize` safely

1. Find the target row with [Find-TableSyncConfig.ps1](analyze-table-batch-sizing.md).
2. Profile the source table and review the advisory range from [Get-TableBatchSizeRecommendation.ps1](analyze-table-batch-sizing.md).
3. If the table is wide or has large-value columns, start near the conservative recommendation.
4. Change only `BatchSize`.
5. Run one controlled sync.
6. Review batch duration, memory pressure, row counts, and any long-running bulk copy messages before increasing further.

## Validate that a change took effect

Look for:

- expected startup log lines
- expected `Sync.RunLog` values
- expected `Sync.RunActionLog` step sequence
- expected row counts or destination changes
- expected checkpoint movement in `Sync.TableState`

## Roll back a bad config change

1. Disable the sync if repeated scheduler attempts are possible.
2. Restore the previous `Sync.TableConfig` values.
3. If checkpoint state was affected, restore the old `Sync.TableState` values too.
4. Run one manual validation execution.
5. Re-enable the sync only after that test passes.

## Investigate behaviour drift

Trace in this order:

1. Launcher script used
2. Exact `SyncName`
3. Current `Sync.TableConfig` row
4. Current `Sync.TableState` row
5. Latest `Sync.RunLog`
6. Matching `Sync.RunActionLog`
7. Source and destination object state

## Trace config row to runtime execution

1. Start with `Sync.TableConfig.SyncName`.
2. Find the launcher that includes that `SyncName`.
3. Confirm the launcher's config server/database/schema constants.
4. Map config fields to runtime code in `Sync-ConfiguredSqlTable.ps1`.
5. Review the latest run/state logs for the same `SyncId`.

## Refresh the database object search index safely

1. Start `Start-SqlTablesSyncWorkspace.ps1` or `Start-SqlObjectSearchService.ps1`.
2. Validate `GET /api/object-search/health`.
3. Run `POST /api/object-search/index/refresh` or `.\Sync-SqlObjectSearchIndex.ps1 -Mode Incremental`.
4. Validate `GET /api/object-search/status`.
5. Search for one known object by exact name and one by definition text before relying on the new index state.

Connection Manager shortcut:

1. Open `Connection Manager`.
2. Make sure the saved profile includes the target server. Add a database only if you want to scope to one database instead of the whole instance.
3. Use `Sync Schema To Search` on that saved profile. With no database selected, the sync enumerates all accessible online user databases on that SQL Server instance.
4. Open the command palette with `Ctrl+K` (`Cmd+K` on macOS) and verify the new database objects appear.

## Rebuild the database object search index safely

1. Confirm the Lucene.NET sidecar is running on loopback only. `Start-SqlTablesSyncWorkspace.ps1` now starts it automatically from `object-search/sql-object-search.settings.json`.
2. Snapshot or note the current `object-search/sql-object-search.settings.json` source list.
3. Run `.\Sync-SqlObjectSearchIndex.ps1 -Mode Full`.
4. Validate `GET /api/object-search/status`.
5. Spot-check tables, views, stored procedures, columns, and indexes from at least one configured source.

## Publish the bundled object-search sidecar safely

1. Run `.\Publish-SqlObjectSearchService.ps1`.
2. Confirm `object-search/bin/win-x64/SqlObjectSearch.Service.exe` exists.
3. Confirm `object-search/sql-object-search.settings.json` still points `service.executablePath` at the intended bundled executable.
4. Start `Start-SqlTablesSyncWorkspace.ps1` and confirm the workspace log says it is using the bundled executable.
5. Validate `GET /api/object-search/health`.
