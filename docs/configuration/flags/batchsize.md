# BatchSize

- Table: `Sync.TableConfig`
- Column: `BatchSize`
- Data type: int
- Allowed values: Positive integer. Tune it as a throughput-versus-memory control, not just a row-count setting.
- Default or observed default: No database default confirmed; store explicitly.
- Null behaviour: Store explicit non-null values unless the field is documented as optional. The runtime mixes helper-based defaults with direct casts.
- Where it is read in code: `Sync-ConfiguredSqlTable.ps1:2524`
- Functional effect: Changes both source `SELECT TOP (...)` read size and `SqlBulkCopy.BatchSize`.
- Side effects: Read once at process start. Mid-run edits do not reconfigure the already-running process.
- Dependencies and conflicts: Review `SyncMode`, `SourceWhereClause`, source row width, large-value columns, and destination log throughput together before changing this field.
- Scope: Usually per sync row in `Sync.TableConfig`; connection fields are also environment-specific.
- Safe to change live: Safe for future runs only. Do not edit `Sync.TableState` during an active run.
- Refresh or restart requirement: No cache refresh exists in the script. Start a new process to pick up the change.
- Example values: `1000`, `5000`, `20000`
- Example scenario: Profile the source table first, choose a conservative value for wide rows or LOB data, then validate one controlled run before increasing further.
- Troubleshooting: If runs stall on one batch, spike memory, or hold long bulk-copy windows, lower this value and re-check the next run log.
- Risk rating: high
- Confidence: confirmed

