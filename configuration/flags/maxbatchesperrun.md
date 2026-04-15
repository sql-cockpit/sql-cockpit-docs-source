# MaxBatchesPerRun

- Table: `Sync.TableConfig`
- Column: `MaxBatchesPerRun`
- Data type: int nullable
- Allowed values: Project-specific string value.
- Default or observed default: `NULL` means unlimited incremental batches.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:2573`, `Sync-ConfiguredSqlTable.ps1:2701`, `Sync-ConfiguredSqlTable.ps1:2861`, `Sync-ConfiguredSqlTable.ps1:2910`, `Sync-ConfiguredSqlTable.ps1:3250`
- Functional effect: Stops incremental processing after the configured number of batches.
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

