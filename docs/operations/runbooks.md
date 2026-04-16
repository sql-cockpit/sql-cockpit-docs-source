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
4. Open the command palette with `Ctrl+K` and verify the new database objects appear.

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
