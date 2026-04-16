# Data Flow

## Incremental mode

```mermaid
flowchart TD
    A[Load Sync.TableConfig + TableState] --> B[Resolve keys, columns, watermark]
    B --> C[Read TOP BatchSize from source with seek predicate]
    C --> D[Bulk copy batch to #StageSync on destination]
    D --> E[Update existing rows or insert missing rows]
    E --> F[Advance LastWatermarkValue / LastKeyValue]
    F --> G[Write TableState + RunActionLog]
    G --> H{More rows?}
    H -->|Yes| C
    H -->|No| I[Write success state and run log]
```

## Full refresh mode

```mermaid
flowchart TD
    A[Load Sync.TableConfig + TableState] --> B[Resolve columns and destination table]
    B --> C[Create #SourceFullRefreshSnapshot on source]
    C --> D[Count and verify snapshot]
    D --> E[Create #FullRefreshStage on destination]
    E --> F[Bulk stream snapshot into destination stage]
    F --> G[Validate staged row count]
    G --> H[Transaction: TRUNCATE or DELETE target then INSERT from stage]
    H --> I[Clear checkpoint values and write success state]
```

## Observed precedence rules

- CLI lookup choice: `-SyncId` wins if supplied; otherwise `-SyncName` is used.
- `SyncMode` defaults to `Incremental` when blank.
- Incremental mode switches to full refresh for that run if the destination table is empty.
- `ColumnsCsv` limits the candidate column set first, then `ExcludeColumnsCsv` removes from that set.
- Key columns and watermark columns must survive final column resolution or the run fails.

## Runtime read timing

- `Sync.TableConfig`: read once at startup.
- `Sync.TableState`: read once at startup, then updated during the run.
- No config reload loop exists.
- Mid-run config edits affect future runs, not the active process.
