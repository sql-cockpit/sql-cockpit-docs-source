# Schema Notes

## What is confirmed

- The runtime uses the `Sync` schema by default for config/state/logging.
- `Get-ConfigRow` joins `Sync.TableConfig` to `Sync.TableState` on `SyncId`.
- `Sync.TableState` rows are created lazily if missing.
- `Sync.RunLog` and `Sync.RunActionLog` are append-oriented audit tables.

## What is inferred

- `Sync.TableConfig.SyncName` should be unique in practice because the lookup throws if more than one row matches.
- `Sync.TableState.SyncId` is expected to be unique because the runtime treats it as a 1:1 state row.
- `RunLog.RunId` is identity-like because the script uses `SCOPE_IDENTITY()`.

## What is not confirmed from repo alone

- Physical data types and constraints for the config tables.
- Whether there are triggers, foreign keys, or audit tables beyond the four tables named above.
- Whether external procedures or jobs also write to these tables.

## Admin guidance

- Prefer explicit non-null values for boolean and numeric config fields because the script sometimes casts raw row values directly instead of using defaulting helpers.
- Avoid ad hoc edits to `LastWatermarkValue` and `LastKeyValue` unless you are intentionally reseeding or rolling back checkpoint state.
- Capture pre-change and post-change row snapshots for any high-risk config edit.
