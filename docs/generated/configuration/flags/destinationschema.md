# DestinationSchema

- Table: `Sync.TableConfig`
- Column: `DestinationSchema`
- Data type: nvarchar
- Allowed values: Project-specific string value.
- Default or observed default: No database default confirmed; store explicitly.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:2734`, `Sync-ConfiguredSqlTable.ps1:2839`, `Sync-ConfiguredSqlTable.ps1:2868`, `Sync-ConfiguredSqlTable.ps1:2882`, `Sync-ConfiguredSqlTable.ps1:2891`, `Sync-ConfiguredSqlTable.ps1:2913`, `Sync-ConfiguredSqlTable.ps1:2918`, `Sync-ConfiguredSqlTable.ps1:3162`, `Sync-ConfiguredSqlTable.ps1:3187`, `Sync-ConfiguredSqlTable.ps1:3189`, `Sync-ConfiguredSqlTable.ps1:3199`, `Sync-ConfiguredSqlTable.ps1:3205`, `Sync-ConfiguredSqlTable.ps1:3211`, `Sync-ConfiguredSqlTable.ps1:3224`, `Sync-ConfiguredSqlTable.ps1:3234`, `Sync-ConfiguredSqlTable.ps1:3251`, `Sync-ConfiguredSqlTable.ps1:3253`, `Sync-ConfiguredSqlTable.ps1:3263`, `Sync-ConfiguredSqlTable.ps1:3269`, `Sync-ConfiguredSqlTable.ps1:3275`, `Sync-ConfiguredSqlTable.ps1:3288`, `Sync-ConfiguredSqlTable.ps1:3298`, `Sync-ConfiguredSqlTable.ps1:3318`, `Sync-ConfiguredSqlTable.ps1:3324`, `Sync-ConfiguredSqlTable.ps1:3326`, `Sync-ConfiguredSqlTable.ps1:3336`, `Sync-ConfiguredSqlTable.ps1:3342`, `Sync-ConfiguredSqlTable.ps1:3348`, `Sync-ConfiguredSqlTable.ps1:3367`, `Sync-ConfiguredSqlTable.ps1:3373`, `Sync-ConfiguredSqlTable.ps1:3383`, `Sync-ConfiguredSqlTable.ps1:3452`, `Sync-ConfiguredSqlTable.ps1:3650`, `Sync-ConfiguredSqlTable.ps1:3655`, `Sync-ConfiguredSqlTable.ps1:3752`, `Sync-ConfiguredSqlTable.ps1:3767`, `Sync-ConfiguredSqlTable.ps1:3771`, `Sync-ConfiguredSqlTable.ps1:3774`, `Sync-ConfiguredSqlTable.ps1:3776`, `Sync-ConfiguredSqlTable.ps1:3786`, `Sync-ConfiguredSqlTable.ps1:3794`, `Sync-ConfiguredSqlTable.ps1:3817`, `Sync-ConfiguredSqlTable.ps1:3821`, `Sync-ConfiguredSqlTable.ps1:3824`, `Sync-ConfiguredSqlTable.ps1:3928`, `Sync-ConfiguredSqlTable.ps1:3937`
- Functional effect: Changes how the runtime connects to or writes to the destination side.
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

