# Analyze Run Logs

Use `Analyze-RunLogs.ps1` to summarize local `.log` files written by the launcher scripts and child sync runs.

The script is read-only. It does not query SQL Server or modify runtime state. It parses the existing `.\Logs` directory and extracts operator-facing fields such as:

- log type: run log or launcher transcript
- sync name derived from the file name
- status: `Success`, `Failed`, `Completed`, `CompletedWithFailures`, `Launcher`, or `Unknown`
- sync mode when the child log recorded it
- start and end timestamps from the log body
- duration from the final sync summary when available
- `RunId` from the state snapshot
- row and batch counts
- heartbeat count
- last step seen before completion or failure
- primary failure message

## Quick usage

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Analyze-RunLogs.ps1
```

This defaults to:

- `Path = .\Logs`
- `Filter = *.log`
- `Latest = 50`
- run logs only unless `-IncludeLauncherLogs` is added

## Common examples

Show the latest failed child logs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Analyze-RunLogs.ps1 `
  -FailedOnly `
  -Latest 20
```

Include launcher transcripts:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Analyze-RunLogs.ps1 `
  -IncludeLauncherLogs `
  -Latest 100
```

Return structured objects for pipeline use:

```powershell
$runs = & .\Analyze-RunLogs.ps1 `
  -PassThru `
  -Latest 200
```

Use in-session invocation with `&` when you want real PowerShell objects. Calling the script through a new `powershell.exe` process converts the output back to plain text.

Emit JSON for another tool:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Analyze-RunLogs.ps1 `
  -IncludeLauncherLogs `
  -AsJson
```

Scan a different folder recursively:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Analyze-RunLogs.ps1 `
  -Path "C:\Temp\SyncLogs" `
  -Recurse `
  -Latest 500
```

## Output fields

| Field | Meaning |
| --- | --- |
| `LogType` | `Run` for child sync logs, `Launcher` for transcript-style launcher logs. |
| `Status` | Parsed outcome. `Success` is confirmed from `Sync complete.`. `Failed` is inferred from error sections or launcher failure patterns. |
| `SyncName` | File-name-based sync identifier. |
| `Mode` | `FullRefresh`, incremental mode, or blank if not present in the log. |
| `RunId` | Value from the `STATE SNAPSHOT` block when present. |
| `StartTime` | First timestamped line in the log, or file timestamp fallback. |
| `EndTime` | Last timestamped line in the log. |
| `Duration` | Final duration from the `Sync complete.` summary or full refresh summary. |
| `RowsRead` | Parsed from `RowsReadTotal`. |
| `RowsMerged` | Parsed from `RowsMergedTotal`. |
| `BatchCount` | Parsed from the summary when present. |
| `HeartbeatCount` | Count of `is still running.` lines. Useful for spotting long-running batches or replacements. |
| `LastStep` | Last `[STEP]` line seen before the log ended. |
| `FailureMessage` | Primary failure text, usually from `ERROR DETAILS` or launcher failure lines. |

## Current parsing rules

Confirmed from current repo log samples:

- Child logs emitted by `Spawn-AptosJobsMemorySafe.Child.ps1` and `Adhoc_RunJobs.ps1` use timestamped lines such as `[2026-03-30 15:50:03] [STEP] ...`.
- Successful runs end with a `Sync complete.` summary line that includes target, mode, duration, rows, and batch count.
- Failures commonly include `ERROR DETAILS`, `STATE SNAPSHOT`, and a follow-up `failed in child launcher` line.
- Launcher transcripts include transcript headers plus `Started ...` and `Completed ... with exit code ...` lines.

Inferred and therefore less stable:

- `SyncName` is derived from the file name, not re-queried from SQL state.
- Launcher status `CompletedWithFailures` is inferred from non-zero child exit codes.
- `Unknown` status means the file did not match the currently observed success or failure markers.

## Operational notes

- Safe change procedure: update the parser when the logging format changes in `Sync-ConfiguredSqlTable.ps1` or the launcher scripts, then rerun `mkdocs build --strict` and test against old and new logs.
- Operational risk: low runtime risk because the script is read-only, but medium support risk if operators rely on fields that are parsed from free-text log lines and those line formats drift.
- Troubleshooting note: if `Duration`, `RowsRead`, or `FailureMessage` are blank, inspect the raw log because the run may have terminated before writing the expected summary block.
