# SQL Cockpit

`SQL Cockpit` is a PowerShell-based SQL tooling suite for analysing schemas, planning migrations, profiling large tables, and moving selected SQL Server data between environments without building a full ETL platform first. The runtime centers on `Sync-ConfiguredSqlTable.ps1`, reads one row from `Sync.TableConfig`, uses `Sync.TableState` as incremental checkpoint state, and writes execution telemetry to `Sync.RunLog` and `Sync.RunActionLog`.

The tool stays lightweight in code footprint, but it still has meaningful operational risk because each database config row acts as part of the runtime control plane. A bad flag, filter, key definition, or SQL hook can redirect data, skip rows, or replace an entire destination table, so the docs treat config tables as operational interface, not just internal storage.

## Practical uses

### Small projects

- Refresh a local developer database from shared test data without copying an entire production-sized backup.
- Move a few lookup or reference tables from an old application database into a new service during a staged migration.
- Keep a reporting table in sync for a small internal dashboard where full warehouse tooling would be overkill.
- Seed UAT or demo environments with a filtered subset of customer, product, or orders data.
- Run one-off or scheduled table moves between legacy SQL Server instances during a small modernization project.

### Enterprise teams

- Shift selected operational tables from legacy SQL Server estates into consolidated platforms during data center exits or cloud migrations.
- Replicate approved tables into downstream reporting, integration, or regional databases with per-table controls.
- Stand up controlled cutover waves where destination tables are pre-created, validated, and backfilled incrementally.
- Feed department-owned databases from shared source systems without giving every team custom sync scripts to maintain.
- Support merger, acquisition, or divestiture projects where only specific schemas or tables need to move on controlled schedules.

## What this documentation covers

- How the sync engine actually works.
- Which config fields are confirmed to affect runtime behaviour.
- Which database tables act as config, state, and audit surfaces.
- How to change flags safely and verify the result.
- How to operate `SQL Cockpit` safely in small and large environments, from straightforward projects to multi-terabyte estates.

## Documentation sections

The docs are organized into role-based sections:

- [User Guide](user/index.md): day-to-day operator workflows in SQL Cockpit.
- [Operations](operations/common-tasks.md): runbooks, troubleshooting, service operations, and release procedures.
- [Configuration](configuration/reference.md): runtime flags and `Sync.TableConfig` semantics.
- [Developer Documentation](developer/index.md): local development, repo split, system contracts, and contribution guidance.
- [Architecture](architecture/overview.md), [Integrations](integrations/overview.md), and [Database](database/config-tables.md): deep technical references.
- [Versioning Guide](VERSIONING.md): how to manage multiple versions of this documentation.

## Quick map

- Start with [Getting Started](getting-started.md) for local orientation.
- Go to [User Guide](user/index.md) for dashboard and operator workflows.
- Go to [Operations](operations/common-tasks.md) for service control, runbooks, and incident handling.
- Go to [Developer Documentation](developer/index.md) when changing code, routes, config behaviour, or docs generation.
- Use [Configuration Reference](configuration/reference.md) before editing `Sync.TableConfig`.
- Use [Runbooks](operations/runbooks.md) and [Troubleshooting](operations/troubleshooting.md) for live support work.

Use the search box in the top navigation to jump directly to flags, tables, scripts, and runbooks. Material for MkDocs search is enabled with suggestions, in-page match highlighting, and shareable search URLs.

## Confidence model

- Confirmed from code: directly visible in PowerShell logic or explicit SQL statements.
- Confirmed from schema usage: inferred from `INSERT`, `UPDATE`, and `SELECT` statements against known tables.
- Inferred: plausible from naming or usage patterns, but not fully proven from the repository alone.
- Uncertain: observed risk or gap that should be verified against the live database or operators.
