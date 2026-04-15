# SourceSchema

- Table: `Sync.TableConfig`
- Column: `SourceSchema`
- Data type: nvarchar
- Allowed values: Project-specific string value.
- Default or observed default: No database default confirmed; store explicitly.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:2552`, `Sync-ConfiguredSqlTable.ps1:2592`, `Sync-ConfiguredSqlTable.ps1:2613`, `Sync-ConfiguredSqlTable.ps1:2638`, `Sync-ConfiguredSqlTable.ps1:2652`, `Sync-ConfiguredSqlTable.ps1:2823`, `Sync-ConfiguredSqlTable.ps1:2830`, `Sync-ConfiguredSqlTable.ps1:2841`, `Sync-ConfiguredSqlTable.ps1:2891`, `Sync-ConfiguredSqlTable.ps1:3229`, `Sync-ConfiguredSqlTable.ps1:3255`, `Sync-ConfiguredSqlTable.ps1:3287`, `Sync-ConfiguredSqlTable.ps1:3306`, `Sync-ConfiguredSqlTable.ps1:3322`, `Sync-ConfiguredSqlTable.ps1:3349`, `Sync-ConfiguredSqlTable.ps1:3370`
- Functional effect: Changes how the runtime connects to or reads from the source side.
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

