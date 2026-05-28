# SourceWhereClause

- Table: `Sync.TableConfig`
- Column: `SourceWhereClause`
- Data type: nvarchar
- Allowed values: SQL predicate fragment valid in `WHERE (...)` against the source object.
- Default or observed default: Blank means no extra filter.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:3053`, `Sync-ConfiguredSqlTable.ps1:3073`, `Sync-ConfiguredSqlTable.ps1:3105`, `Sync-ConfiguredSqlTable.ps1:3106`, `Sync-ConfiguredSqlTable.ps1:3137`, `Sync-ConfiguredSqlTable.ps1:3463`, `Sync-ConfiguredSqlTable.ps1:3470`, `Sync-ConfiguredSqlTable.ps1:3490`, `Sync-ConfiguredSqlTable.ps1:3496`, `Sync-ConfiguredSqlTable.ps1:3497`, `Sync-ConfiguredSqlTable.ps1:3503`, `Sync-ConfiguredSqlTable.ps1:3529`, `Sync-ConfiguredSqlTable.ps1:3545`, `Sync-ConfiguredSqlTable.ps1:3575`
- Functional effect: Restricts source reads, counts, and snapshots.
- Side effects: Read once at process start. Mid-run edits do not reconfigure the already-running process.
- Dependencies and conflicts: Review interactions with `SyncMode`, column selection, and `Sync.TableState` checkpoints before changing this field.
- Scope: Usually per sync row in `Sync.TableConfig`; connection fields are also environment-specific.
- Safe to change live: Safe for future runs only. Do not edit `Sync.TableState` during an active run.
- Refresh or restart requirement: No cache refresh exists in the script. Start a new process to pick up the change.
- Example values: `example-value`
- Example scenario: Validate the next run using `Sync.RunLog` and `Sync.RunActionLog` after changing this field.
- Troubleshooting: Trace the active config row, then compare runtime log output with the stored value.
- Risk rating: high
- Confidence: confirmed

