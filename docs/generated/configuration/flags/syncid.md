# SyncId

- Table: `Sync.TableConfig`
- Column: `SyncId`
- Data type: int
- Allowed values: Positive integer unless the operating model explicitly allows `0`.
- Default or observed default: No database default confirmed; store explicitly.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:2655`, `Sync-ConfiguredSqlTable.ps1:2663`, `Sync-ConfiguredSqlTable.ps1:2719`, `Sync-ConfiguredSqlTable.ps1:2723`, `Sync-ConfiguredSqlTable.ps1:2743`, `Sync-ConfiguredSqlTable.ps1:2849`, `Sync-ConfiguredSqlTable.ps1:2873`, `Sync-ConfiguredSqlTable.ps1:2922`, `Sync-ConfiguredSqlTable.ps1:3003`, `Sync-ConfiguredSqlTable.ps1:3411`, `Sync-ConfiguredSqlTable.ps1:3433`, `Sync-ConfiguredSqlTable.ps1:3640`, `Sync-ConfiguredSqlTable.ps1:3718`, `Sync-ConfiguredSqlTable.ps1:3724`, `Sync-ConfiguredSqlTable.ps1:3748`, `Sync-ConfiguredSqlTable.ps1:3888`, `Sync-ConfiguredSqlTable.ps1:3921`, `Sync-ConfiguredSqlTable.ps1:3933`, `Sync-ConfiguredSqlTable.ps1:3944`, `Sync-ConfiguredSqlTable.ps1:3965`, `Sync-ConfiguredSqlTable.ps1:4000`, `Sync-ConfiguredSqlTable.ps1:4015`, `Sync-ConfiguredSqlTable.ps1:4054`
- Functional effect: Changes runtime behaviour for this sync definition.
- Side effects: Read once at process start. Mid-run edits do not reconfigure the already-running process.
- Dependencies and conflicts: Review interactions with `SyncMode`, column selection, and `Sync.TableState` checkpoints before changing this field.
- Scope: Usually per sync row in `Sync.TableConfig`; connection fields are also environment-specific.
- Safe to change live: Safe for future runs only. Do not edit `Sync.TableState` during an active run.
- Refresh or restart requirement: No cache refresh exists in the script. Start a new process to pick up the change.
- Example values: `example-value`
- Example scenario: Validate the next run using `Sync.RunLog` and `Sync.RunActionLog` after changing this field.
- Troubleshooting: Trace the active config row, then compare runtime log output with the stored value.
- Risk rating: medium
- Confidence: confirmed

