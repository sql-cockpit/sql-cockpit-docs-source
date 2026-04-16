# Config Tables

## `Sync.TableConfig`

Purpose:

- one row per sync definition
- contains source, destination, mode, column, key, retry, and hook settings

Confirmed runtime columns used by the script:

- `SyncId`
- `SyncName`
- `IsEnabled`
- `SyncMode`
- `SourceServer`
- `SourceDatabase`
- `SourceSchema`
- `SourceTable`
- `SourceAuthMode`
- `SourceUsername`
- `SourcePassword`
- `DestinationServer`
- `DestinationDatabase`
- `DestinationSchema`
- `DestinationTable`
- `DestinationAuthMode`
- `DestinationUsername`
- `DestinationPassword`
- `CommandTimeoutSeconds`
- `BatchSize`
- `RetryCount`
- `RetryDelaySeconds`
- `KeyColumnsCsv`
- `ColumnsCsv`
- `ExcludeColumnsCsv`
- `WatermarkColumn`
- `WatermarkType`
- `FullScanAllow`
- `InsertOnly`
- `MaxBatchesPerRun`
- `AutoCreateDestinationTable`
- `CreatePrimaryKeyOnAutoCreate`
- `ValidateDestinationSchema`
- `SourceWhereClause`
- `PreSyncSql`
- `PostSyncSql`

Note:

- `Get-ConfigRow` selects `c.*`, so the physical table may contain more columns than the current runtime uses.

## `Sync.TableState`

Purpose:

- stores checkpoint state and last-run summary by `SyncId`

Confirmed columns from `SELECT` and `UPDATE` statements:

- `SyncId`
- `LastWatermarkValue`
- `LastKeyValue`
- `LastSyncStartUtc`
- `LastSyncEndUtc`
- `LastStatus`
- `LastMessage`
- `LastRowsRead`
- `LastRowsMerged`
- `LastBatchCount`
- `ConsecutiveFailureCount`
- `LastSuccessfulWatermarkValue`
- `LastSuccessfulSyncEndUtc`

Operational note:

- Incremental mode reads checkpoint values from here.
- Full refresh clears `LastWatermarkValue` and `LastKeyValue`.

## `Sync.RunLog`

Purpose:

- one row per sync execution
- captures start and end status plus source/destination context

Confirmed columns from `INSERT` and `UPDATE` statements:

- `RunId`
- `SyncId`
- `SyncName`
- `RunStartUtc`
- `RunEndUtc`
- `Status`
- `Message`
- `SourceServer`
- `SourceDatabase`
- `SourceSchema`
- `SourceTable`
- `DestinationServer`
- `DestinationDatabase`
- `DestinationSchema`
- `DestinationTable`
- `WatermarkColumn`
- `WatermarkType`
- `WatermarkStartValue`
- `WatermarkEndValue`
- `RowsRead`
- `RowsMerged`
- `BatchCount`
- `HostName`
- `ExecutedBy`

## `Sync.RunActionLog`

Purpose:

- step-level event log per run or partial run

Confirmed columns from `INSERT` statements:

- `SyncId`
- `RunId`
- `ActionUtc`
- `ActionType`
- `ActionStatus`
- `Details`

Common action types observed:

- `SyncStart`
- `SchemaValidation`
- `DestinationTableCreated`
- `PreSyncSql`
- `BatchSynced`
- `SourceSnapshotCreated`
- `FullRefreshBatchStaged`
- `FullRefreshStageValidated`
- `FullRefreshDestinationReplaced`
- `PostSyncSql`
- `DestinationCountValidated`
- `SyncComplete`
- `SyncFailed`
