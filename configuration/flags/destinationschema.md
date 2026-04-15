# DestinationSchema

- Table: `Sync.TableConfig`
- Column: `DestinationSchema`
- Data type: nvarchar
- Allowed values: Project-specific string value.
- Default or observed default: No database default confirmed; store explicitly.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:2596`, `Sync-ConfiguredSqlTable.ps1:2611`, `Sync-ConfiguredSqlTable.ps1:2640`, `Sync-ConfiguredSqlTable.ps1:2654`, `Sync-ConfiguredSqlTable.ps1:2663`, `Sync-ConfiguredSqlTable.ps1:2685`, `Sync-ConfiguredSqlTable.ps1:2690`, `Sync-ConfiguredSqlTable.ps1:2934`, `Sync-ConfiguredSqlTable.ps1:2959`, `Sync-ConfiguredSqlTable.ps1:2961`, `Sync-ConfiguredSqlTable.ps1:2971`, `Sync-ConfiguredSqlTable.ps1:2977`, `Sync-ConfiguredSqlTable.ps1:2983`, `Sync-ConfiguredSqlTable.ps1:2996`, `Sync-ConfiguredSqlTable.ps1:3006`, `Sync-ConfiguredSqlTable.ps1:3023`, `Sync-ConfiguredSqlTable.ps1:3025`, `Sync-ConfiguredSqlTable.ps1:3035`, `Sync-ConfiguredSqlTable.ps1:3041`, `Sync-ConfiguredSqlTable.ps1:3047`, `Sync-ConfiguredSqlTable.ps1:3060`, `Sync-ConfiguredSqlTable.ps1:3070`, `Sync-ConfiguredSqlTable.ps1:3090`, `Sync-ConfiguredSqlTable.ps1:3096`, `Sync-ConfiguredSqlTable.ps1:3098`, `Sync-ConfiguredSqlTable.ps1:3108`, `Sync-ConfiguredSqlTable.ps1:3114`, `Sync-ConfiguredSqlTable.ps1:3120`, `Sync-ConfiguredSqlTable.ps1:3139`, `Sync-ConfiguredSqlTable.ps1:3145`, `Sync-ConfiguredSqlTable.ps1:3155`, `Sync-ConfiguredSqlTable.ps1:3231`, `Sync-ConfiguredSqlTable.ps1:3429`, `Sync-ConfiguredSqlTable.ps1:3434`, `Sync-ConfiguredSqlTable.ps1:3536`, `Sync-ConfiguredSqlTable.ps1:3551`, `Sync-ConfiguredSqlTable.ps1:3555`, `Sync-ConfiguredSqlTable.ps1:3558`, `Sync-ConfiguredSqlTable.ps1:3560`, `Sync-ConfiguredSqlTable.ps1:3570`, `Sync-ConfiguredSqlTable.ps1:3578`, `Sync-ConfiguredSqlTable.ps1:3601`, `Sync-ConfiguredSqlTable.ps1:3605`, `Sync-ConfiguredSqlTable.ps1:3608`, `Sync-ConfiguredSqlTable.ps1:3712`, `Sync-ConfiguredSqlTable.ps1:3721`
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

