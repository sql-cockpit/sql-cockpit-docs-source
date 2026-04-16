# User Documentation

This section is for operators, analysts, and anyone using SQL Cockpit to inspect SQL Server estates, manage reusable connections, create sync rows, or support live sync jobs.

Use these pages when you need to do the work safely without reading the implementation first.

## Start Here

- [First Run](first-run.md): start the local workspace and open SQL Cockpit.
- [Local Auth And Preferences](local-auth-and-preferences.md): create the first local account, sign in, and understand what the packaged local database stores.
- [Dashboard Guide](dashboard-guide.md): understand the browser pages and what each one is for.
- [Desktop Service Manager](desktop-service-manager.md): operate background SQL Cockpit runtime components from the GUI.
- [Connection And Instance Profiles](connection-and-instance-profiles.md): choose between database connections and server-level instance profiles.
- [Sync Configuration Workflow](sync-configuration-workflow.md): create, preview, import, and check sync rows.
- [Operational Safety](operational-safety.md): make changes with a rollback path and useful evidence.

## URL Scheme

User documentation lives under:

```text
/user/
```

Developer documentation lives under:

```text
/developer/
```

Reference material that both audiences need remains in shared areas such as `/configuration/`, `/operations/`, `/integrations/`, and `/database/`.

## Common Jobs

| Job | Start here |
| --- | --- |
| Open SQL Cockpit | [First Run](first-run.md) |
| Sign in or change the local password | [Local Auth And Preferences](local-auth-and-preferences.md) |
| Save a SQL Server instance | [Connection And Instance Profiles](connection-and-instance-profiles.md) |
| Save a database connection | [Connection And Instance Profiles](connection-and-instance-profiles.md) |
| Browse a server or database | [Dashboard Guide](dashboard-guide.md) |
| Start, stop, or restart desktop background services | [Desktop Service Manager](desktop-service-manager.md) |
| Create a new sync row | [Sync Configuration Workflow](sync-configuration-workflow.md) |
| Check why a run failed | [Operational Safety](operational-safety.md) and [Analyze Run Logs](../operations/analyze-run-logs.md) |
| Understand a config field | [Configuration Reference](../configuration/reference.md) |
