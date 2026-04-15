# Known Issues

## Confirmed gaps

- The repo does not contain a full schema export for the `Sync` tables.
- The repo does not contain scheduler definitions or production orchestration metadata.
- `Get-ConfigRow` selects `c.*`, so unused physical columns may exist in `Sync.TableConfig` without any visibility here.

## Sensitive files

- `Test-Connection.ps1` contains an inline connection string.
- `TestLogin.ps1` contains inline credentials.

Treat both as sensitive and review whether they should remain in the repository.

## Likely legacy or incomplete paths

- `Spawn-SyncJobs.ps1` has the actual `Start-Process` call commented out.
- `Spawn-SyncJobs.ps1` should be verified before anyone relies on it operationally.

## Risky design traits

- Database config values can execute SQL directly through `PreSyncSql`, `PostSyncSql`, and `SourceWhereClause`.
- Full refresh can replace an entire destination table in one run.
- Several boolean and integer fields appear to expect explicit non-null values.
