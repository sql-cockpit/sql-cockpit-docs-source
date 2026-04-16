# Glossary

- Sync row: one `Sync.TableConfig` definition plus its matching `Sync.TableState`.
- Incremental mode: seek-paged sync that advances stored key and optional watermark state.
- Full refresh: snapshot, stage, and full destination replacement flow.
- Watermark: source column plus stored value used to resume from a change point.
- Key-only paging: incremental paging that uses the configured key without a watermark.
- Stage table: destination temp table used to bulk load a batch or full-refresh snapshot before merge or replacement.
- Snapshot table: source temp table used only in full refresh mode.
- Applock: SQL Server application lock used to prevent overlapping runs for the same `SyncName`.
- Config database: SQL database that stores `Sync.TableConfig`, `Sync.TableState`, `Sync.RunLog`, and `Sync.RunActionLog`.
