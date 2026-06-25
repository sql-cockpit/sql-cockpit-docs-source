# SQL Cockpit Invocation Framework

The SQL Server invocation bridge lets T-SQL call controlled SQL Cockpit PowerShell commands through a fixed stored procedure API:

```sql
EXEC [SqlCockpit].Cockpit.Invoke
    @CommandName = N'FetchRemote',
    @JsonPayload = @Payload,
    @InvocationId = @InvocationId OUTPUT;
```

The bridge installs into a dedicated control database, normally `[SqlCockpit]`, and stores audit rows in `Cockpit.InvocationLog` plus captured command output in `Cockpit.InvocationOutput`. Application databases should call the bridge by three-part name rather than hosting bridge objects locally.

## Dashboard Monitoring

Open `/sql-bridge` in the SQL Cockpit dashboard to inspect bridge calls. The SQL Bridge dashboard is split into focused read-only pages:

- `/sql-bridge`: overview counters, bridge target, refresh controls, and links into the focused pages.
- `/sql-bridge/history`: filter procedure-run history, expand one stored procedure run, inspect child SQL Bridge syncs and trace/log events, open one child invocation, inspect captured output, review the redacted effective payload, and copy an equivalent `Cockpit.Invoke` SQL batch generated from the stored payload.
- `/sql-bridge/profiler`: select one stored procedure run and inspect query-source blocks, SQL Bridge sync milestones, and trace events as proportional timing blocks.
- `/sql-bridge/locks`: inspect active `FetchRemote` destination locks, identify the owning SQL Server session, and let local administrators release confirmed stale sessions.
- `/sql-bridge/usage`: copy short starter T-SQL calls for common bridge wrapper procedures.

The dashboard uses these endpoints:

| Method | Path | Permission | Purpose |
| --- | --- | --- | --- |
| `GET` | `/api/sql-bridge/invocations` | `tasks.view` or local admin | List recent SQL bridge invocations, or use `view=procedureRuns` to page by stored procedure run with nested syncs and trace/log events. |
| `GET` | `/api/sql-bridge/invocations/{id}` | `tasks.view` or local admin | Read one invocation, up to 500 output rows, redacted payloads, and an equivalent reconstructed `Cockpit.Invoke` SQL batch. |
| `GET` | `/api/sql-bridge/locks` | `tasks.view` or local admin | List active SQL Cockpit `FetchRemote` app locks with session owner, source/destination context, active request details, and bridge refresh state. |
| `POST` | `/api/sql-bridge/locks/kill` | local admin only | Kill a confirmed stale SQL Server session that owns a SQL Cockpit `FetchRemote` lock through `Cockpit.KillBridgeLockSession`. |

The invocation and lock-list endpoints read the bridge control database and SQL Server lock/session DMVs only. They do not run PowerShell, start `xp_cmdshell`, execute `Cockpit.Invoke`, or change command defaults. The kill endpoint is destructive and intentionally local-admin only; it refuses to kill the current session, requires the target to hold a SQL Cockpit `FetchRemote` lock, and refuses active SQL requests unless `allowRunning` is explicitly passed. The dashboard kill button uses a confirmation prompt and does not set `allowRunning`.

The history and profiler pages default to `GET /api/sql-bridge/invocations?view=procedureRuns`. Each table row is one stored procedure run keyed by `metadata.caller.runId` / trace run id. Expanding a row shows the sync invocations and `Cockpit.TraceEventLog` entries for that run. The profiler uses the same response and converts ordered trace events into timed blocks: `SqlStatementStart` events become query-source blocks, bridge start/end milestones become bridge blocks, and each duration is measured to the next recorded event or the run end. Profiler colours are duration-first: green is under 10 seconds, cyan is 10 seconds to 1 minute, blue is 1-5 minutes, amber is 5-15 minutes, orange is 15-30 minutes, and red is 30 minutes or longer. The slowest relative blocks in shorter runs can also be promoted into warmer bands so refactor candidates stand out. This requires generated debug tracing or explicit `Cockpit.TraceEvent` calls; runs without statement trace events still appear, but the profiler has no query blocks to draw. A generated procedure run remains `Started` while its trace session is open on a procedure activity event such as `SqlStatementStart` or bridge sync start/end, even when the latest bridge invocation has already completed, because the stored procedure may still be executing ordinary SQL between trace events. The expanded procedure timeline defaults to newest-first ordering so active runs show the latest signal immediately; operators can switch an individual expanded run to oldest-first when they need to read the execution from the start. New procedure-run rows, sync rows, and trace/log rows briefly fade in after refresh so operators can spot newly arrived activity. Older rows without run metadata are shown as standalone bridge calls instead of being guessed into a shared procedure group.

The detail endpoint includes `payload`, `originalPayload` when `Cockpit.Invoke` recorded a pre-defaults caller payload, `apiCall`, `sourceQuery`, and `invocationSql.sql`. The SQL is reconstructed from the stored JSON payload after password/token/key-like values are redacted. SQL Server does not record the caller's exact wrapper batch text or the `FetchRemote` metadata-resolved column list, so invocations originally made with wrappers such as `Cockpit.FetchRemote` are displayed as equivalent low-level `Cockpit.Invoke` calls plus a representative source `SELECT`. Omitting `view=procedureRuns` from the list endpoint keeps the legacy flat `invocations[]` response for API consumers.

Current limitation: the SQL bridge writes `Cockpit.InvocationOutput` after the blocking `xp_cmdshell` call finishes, so stdout is not streamable for running calls. The dashboard still shows `Started` rows and recalculates elapsed time from the recorded `StartedAt` value once per second while running rows are visible; final output and row counts appear when the invocation completes.

For failed calls, the dashboard should treat `Cockpit.InvocationLog.ErrorMessage` as the canonical full error text. The PowerShell executor writes the full single-line exception there through its local SQL connection when possible; if that is unavailable, it emits compact `ERROR` detail chunks that `Cockpit.Invoke` stitches back together. `Cockpit.InvocationOutput` remains the captured stdout stream and its first structured `ERROR` row is intentionally compact because it passes through `xp_cmdshell`.

The dashboard refresh control defaults to 30 seconds, can be changed to 10 seconds, 1 minute, 2 minutes, 5 minutes, or `Off`, and shows a countdown to the next poll. Auto-refresh only runs while running invocations are visible or the status filter is `Started`. When polling adds newer rows to the history view, those rows briefly fade in with a left-edge highlight so operators can spot fresh invocations.

The usage page includes copyable T-SQL snippets for common wrapper calls such as `Cockpit.FetchRemote`, `Cockpit.FetchRemoteIncremental`, `Cockpit.ListProfiles`, and `Cockpit.ListDatabases`. The snippets are examples only and do not execute until an operator pastes them into SQL Server.

## Configuration

| Setting | Storage | Valid values | Default | Code paths affected | Operational risk | Safe change procedure |
| --- | --- | --- | --- | --- | --- | --- |
| `SQL_COCKPIT_BRIDGE_CONFIG_PATH` / `--sqlBridgeConfigPath` | Web process environment or CLI option | Absolute path to `CockpitInvoke.config.json` | First existing config under `C:\ProgramData\SqlCockpit` or `E:\Program Files\SqlCockpit` | `sql-cockpit-api/lib/sql-bridge-invocations.js` | Wrong path can point the dashboard at the wrong bridge database name or leave it on defaults. | Set explicitly on shared hosts, restart the web process, call `/api/sql-bridge/invocations`, and verify `bridge.configPath`. |
| `SQL_COCKPIT_BRIDGE_SQL_SERVER` / `--sqlBridgeSqlServer` | Web process environment or CLI option | SQL Server name reachable with Windows auth | `localhost` | `/sql-bridge`, `/api/sql-bridge/invocations*` | Wrong server can show another environment's bridge history or fail with connection errors. | Set in staging first, restart, and compare one invocation id with SSMS. |
| `SQL_COCKPIT_BRIDGE_DATABASE` / `--sqlBridgeDatabase` | Web process environment or CLI option | SQL Server database name | Installed `cockpitDatabase`, then `SqlCockpit` | `/sql-bridge`, `/api/sql-bridge/invocations*` | Wrong database hides or exposes the wrong invocation history. | Set with the server value, restart, and verify the returned `bridge.database`. |
| SQL Bridge dashboard refresh interval | Browser state in `/sql-bridge` | `Off`, `10`, `30`, `60`, `120`, or `300` seconds | `30` seconds | `/sql-bridge`, `/sql-bridge/history`, and `/sql-bridge/profiler` client polling of `/api/sql-bridge/invocations*` | Shorter intervals increase read load on the bridge control database. Profiler views also expose debug trace volume when statement tracing is enabled. | Use `Off` or a longer interval for shared monitoring screens; use `Started` plus a short interval only while actively watching a running invocation. |
| SQL Bridge lock dashboard | `/sql-bridge/locks`; `GET /api/sql-bridge/locks`; `POST /api/sql-bridge/locks/kill` | Read requires `tasks.view` or local admin; kill requires local admin; kill body accepts `sessionId`, optional `lockResource`, optional `reason`, optional `allowRunning` | Disabled kill button for non-admins; kill refuses running sessions by default | Lets operators see blocked destination refresh locks and lets admins release stale SQL sessions without manually querying DMVs. | High for kill: SQL Server rolls back the target session and releases all locks it owns. | Match failed invocation lock resource, session id, host/login/program, and idle status before killing. Refresh the lock page before restarting the blocked job. |
| Wrapper invocation name | `Cockpit.FetchRemote @DefaultName`; `Cockpit.FetchRemoteIncremental @DefaultName` | Any non-empty text up to 200 characters; for incremental calls it must also be a safe state name when `@StateName` is omitted | Omitted | Wrapper calls copy this to `metadata.correlationId` unless `@CorrelationId` is supplied. | Reusing an incremental name for unrelated work can reuse checkpoint state if no explicit `@StateName` is supplied. | Use job/table names such as `erpmdb_cloud_ib_allocation_copy`; pass `@CommandDefaultName` only for reusable JSON templates. |
| Wrapper command default selector | `Cockpit.FetchRemote @CommandDefaultName`; `Cockpit.FetchRemoteIncremental @CommandDefaultName` | Existing `Cockpit.CommandDefault.DefaultName`, letters/digits/`_`/`.`/`-`, up to 100 characters | Omitted | Wrapper calls map this to low-level JSON `defaultName`. | Wrong defaults can point a copy at the wrong profile or destination. | Review `Cockpit.CommandDefault`, test low-volume copies, and keep `@DefaultName` for the run name. |
| FetchRemote destination mode inference | `Cockpit.FetchRemote @DestinationMode`; destination selector parameters | `ResultSet`, `LocalTable`, or `Csv`; omitted with destination profile/database/table selectors infers `LocalTable` | Omitted | Keeps copy-style calls short while preserving `ResultSet` behavior for calls without a destination. | Accidental destination selectors can turn a preview into a write. | Pass `@DestinationMode = N'ResultSet'` for preview-only calls and review destination parameters before running. |
| FetchRemote bridge lock timeout | `Cockpit.FetchRemote @BridgeLockTimeoutSeconds`; `Cockpit.BridgeConfig.DefaultBridgeLockTimeoutSeconds`; generated Procedure Repointer variable `@CockpitBridgeLockTimeoutSeconds` | `NULL` or integer `>= 0`; when the parameter is `NULL`, the wrapper reads `DefaultBridgeLockTimeoutSeconds`; generated Procedure Repointer SQL uses `60` by default | `DefaultBridgeLockTimeoutSeconds = 60`; generated repointer default `60` | Bounds how long a waiting caller can block on the destination-table `sp_getapplock` before a timeout is logged. Existing generated procedures that still pass `NULL` inherit the bridge config default after redeploy. Timeout/skipped rows update `Cockpit.BridgeRefreshState.LastInvocationId`, start/finish timestamps, rows, and error details against the timeout invocation. | Too short can fail normal overlap; too long can tie up SQL Agent workers. A killed SSMS run can leave the owning SQL session active briefly while PowerShell unwinds, and that active session can continue holding the session-owned app lock. | Start generated repointer jobs at 60 seconds. Use 0 for fail-fast overlap detection. Change the config row through a reviewed DBA script, then run one low-volume overlap test. On timeout, inspect `Cockpit.InvocationOutput.ParsedJson.lockResource`, `Cockpit.BridgeRefreshState`, and `sys.dm_tran_locks` / `sys.dm_exec_sessions` before killing any session. |
| Bridge lock administration procedures | `Cockpit.ListBridgeLocks`; `Cockpit.KillBridgeLockSession` | List all locks or one `@LockResource`; kill by `@SessionId` with optional `@LockResource`, `@AllowRunning`, and `@Reason` | Installed by the bridge; administrator-only | Gives DBAs a supported way to inspect and clear stale SQL Cockpit `FetchRemote` application locks after an SSMS cancellation or disconnected client leaves a session open. | High: killing a SQL session can roll back work or disconnect an operator's SSMS tab. Requires SQL Server permission to view server state and kill sessions. | Run `EXEC Cockpit.ListBridgeLocks;`, match the lock resource from the failed invocation output, confirm host/login/program/status, then run `EXEC Cockpit.KillBridgeLockSession @SessionId = <id>, @LockResource = N'<resource>', @Reason = N'<incident>';`. |
| Incremental bridge state | `Cockpit.IncrementalState` | `StateName` with letters, digits, `_`, `.`, `-`; one required key column; optional watermark column/type; checkpoint values stored as strings; source server/database/schema/table/filter and destination server/database/schema/table are part of the state contract | Created by first `Cockpit.FetchRemoteIncremental` run | `Cockpit.FetchRemoteIncremental`, `sql-server-bridge/powershell/modules/Cockpit.Commands.psm1` | Wrong checkpoint edits can skip or replay rows; append-oriented destinations can duplicate changed rows unless the destination is a staging table or constrained. Reusing a state name for a different filter or target is rejected unless reset is explicit. | Use a dedicated state name per source/destination/filter/key contract, run one chunk first, inspect `LastWatermarkValue`/`LastKeyValue`, then increase chunk count. |

## FetchRemoteIncremental

`Cockpit.FetchRemoteIncremental` is the wrapper for key/watermark chunked table copies. It uses saved profiles and `SqlBulkCopy` like `Cockpit.FetchRemote`, but stores progress in `Cockpit.IncrementalState` and advances the checkpoint only after a chunk has copied successfully.

```sql
DECLARE @RowsAffected bigint;
DECLARE @ChunksCopied int;

EXEC Cockpit.FetchRemoteIncremental
    @DefaultName = N'erpmdb_cloud_sku_incremental',
    @CommandDefaultName = N'IncrementalLocalTableCopy',
    @SourceDatabase = N'me_pc_01',
    @SourceTable = N'sku',
    @KeyColumn = N'sku_id',
    @WatermarkColumn = N'updated_at',
    @ChunkSize = 5000,
    @MaxChunks = 1,
    @DestinationProfileName = N'nascar / EPC_Imports_PCK',
    @DestinationTable = N'sku',
    @RowsAffected = @RowsAffected OUTPUT,
    @ChunksCopied = @ChunksCopied OUTPUT;
```

`@MaxChunks = 1` is the default for controlled job-style polling. `@MaxChunks = 0` keeps copying until no rows remain and should be reserved for approved catch-up windows.

## Troubleshooting

If SQL Server raises `Msg 1934` about incorrect SET options such as `QUOTED_IDENTIFIER`, redeploy `sql-server-bridge/sql/003_create_procedures.sql`. The bridge log tables use filtered indexes, so `Cockpit.Invoke` must be created with `QUOTED_IDENTIFIER ON` and runtime indexed-view-compatible SET options.

```sql
SELECT
    OBJECTPROPERTYEX(OBJECT_ID(N'Cockpit.Invoke'), N'ExecIsQuotedIdentOn') AS InvokeQuotedIdentifierOn,
    OBJECTPROPERTYEX(OBJECT_ID(N'Cockpit.FetchRemote'), N'ExecIsQuotedIdentOn') AS FetchRemoteQuotedIdentifierOn;
```

## Safe Test Procedure

1. Confirm the SQL Cockpit web process can connect to the bridge control database with Windows authentication.
2. Sign in as a local admin or a user with `tasks.view`.
3. Open `/sql-bridge` and verify recent invocations appear.
4. Expand a completed invocation and compare `RowsAffected` plus the generated invocation SQL with `Cockpit.InvocationLog`.
5. Open `/sql-bridge/profiler`, select a procedure run with `SqlStatementStart` trace events, and confirm query-source timing blocks render.
6. Open `/sql-bridge/locks` and confirm active locks are listed, or the empty state appears when no `FetchRemote` lock is held.
7. Open `/api-docs` and confirm the `SQL Bridge` tag lists invocation, lock-list, and lock-kill endpoints.
