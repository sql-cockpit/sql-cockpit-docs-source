# Jobs And Schedulers

## What exists in repo

Hard-coded job lists exist in:

- `Spawn-AptosJobs.ps1`
- `Spawn-AptosJobsMemorySafe.ps1`
- `Adhoc_RunJobs.ps1`
- `Spawn-SyncJobs.ps1`

## What does not exist in repo

- job schedule definitions
- central scheduler configuration
- retry scheduler
- queue or worker service

## Operational implication

This repo contains job launch orchestration, not schedule orchestration.

When documenting production behaviour, verify:

- who invokes these scripts
- how often they run
- whether multiple launchers can target the same `SyncName`
- whether external schedulers restart failed jobs automatically

## Launcher-specific notes

### Memory-safe launchers

`Spawn-AptosJobsMemorySafe.ps1` and `Adhoc_RunJobs.ps1` throttle based on:

- `MaxConcurrent`
- `PollSeconds`
- `MinFreeMemoryGB`

These are launcher-level controls, not per-sync config table fields.

### `Spawn-SyncJobs.ps1`

- Contains a hard-coded job list.
- Has `Start-Process` commented out.
- Treat it as legacy or incomplete until verified otherwise.
