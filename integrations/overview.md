# Integrations Overview

## Confirmed external dependency

Microsoft SQL Server is still the core system integration surface.

The runtime integrates with:

- one config SQL database
- one source SQL database per sync row
- one destination SQL database per sync row

## New local integration surfaces

This repo now also exposes three local operator and automation interfaces:

- `Start-SqlTablesSyncRestApi.ps1`
- `Start-SqlTablesSyncMcpServer.ps1`
- `Start-SqlTablesSyncDocsServer.ps1`
- the built-in `SQL Cockpit` Next.js web app served by the Node host launched from `Start-SqlTablesSyncRestApi.ps1` at `/` and `/app`

For operator convenience, `Start-SqlTablesSyncWorkspace.ps1` can launch the docs host and REST API together. The web app then becomes available automatically through the API root.

These do not replace the sync runner. They provide a controlled way for automation and AI tools to:

- list sync definitions from `Sync.TableConfig`
- create one sync definition with preview support
- preview or import multiple sync definitions from CSV
- filter and inspect the current sync fleet from a browser dashboard
- inspect live SQL Server table schemas
- profile live SQL tables for advisory `BatchSize` guidance
- generate migration scripts for destination tables

## Confirmed SQL Server features used

- standard T-SQL queries and DML
- temp tables
- `sp_getapplock`
- `sp_releaseapplock`
- DMV queries for diagnostics
- `IDENTITY_INSERT`
- `TRUNCATE TABLE` with `DELETE` fallback
- `SqlBulkCopy`
- `sys.columns`, `sys.types`, `sys.key_constraints`, and related catalog views for migration planning

## Integration risks

- source and destination auth drift
- schema drift
- key mismatch
- invalid `SourceWhereClause`
- destination-side SQL hooks with hidden downstream dependencies
- exposing the REST API or MCP server beyond loopback without a security review
- enabling rows too early through the web app or write API
- using the dashboard migration or batch-analysis tools against the wrong environment target
- partial success during CSV import when `continueOnError = true`
- returning stored SQL-auth credentials from live config rows to automation clients

## Confirmed vs inferred

- Confirmed: the REST API, built-in web app, and MCP server are local entry points in this repo and all rely directly or indirectly on `SqlTablesSync.Tools.psm1`.
- Confirmed: the dashboard is now hosted by Node.js, while PowerShell remains the business-logic execution layer behind the HTTP routes.
- Confirmed: no new database configuration flags or control tables were added.
- Inferred: if these interfaces are exposed remotely, they become a sensitive operational boundary because they can reveal connection details already stored in `Sync.TableConfig` and now also create new config rows.
