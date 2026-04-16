# Connection And Instance Profiles

SQL Cockpit has two profile types because server-level workflows and database-level workflows need different scopes.

## Which One Should I Use?

| Need | Use | Why |
| --- | --- | --- |
| Browse databases on a SQL Server | Instance Manager | The workflow starts at the server and may span many databases. |
| Inspect SQL Agent jobs | Instance Manager | SQL Agent metadata lives at the instance level in `msdb`. |
| Search objects across an instance | Instance Manager | Object search indexes server/database/schema/object metadata. |
| Create a source or destination database profile | Connection Manager | Sync planning needs a specific database. |
| Test one database login | Connection Manager | The validation is database-scoped. |

## Instance Profiles

Instance profiles are saved by `Instance Manager` in browser local storage key `sql-cockpit-instance-profiles`.

They include:

- profile name
- server name
- authentication mode
- SQL username and password when using SQL authentication
- integrated-security setting
- trust-server-certificate setting

Use instance profiles for workflows that do not start with a single database.

## Database Connection Profiles

Database connection profiles are saved by `Connection Manager` in browser local storage key `sql-cockpit-database-connection-profiles`.

They include the instance fields plus a database name. They do not automatically create or update rows in `Sync.TableConfig`.

Use database connection profiles when planning or validating source and destination database work.

## Safe Profile Handling

1. Prefer integrated security where the workstation account is the approved operator identity.
2. Avoid saving SQL-auth passwords on shared workstations.
3. Test profiles before using them in Server Explorer, Agent Manager, or sync planning.
4. Delete stale profiles after server aliases, roles, or credentials change.
5. Remember that browser local storage does not roam to another browser, machine, or dashboard origin.

## Troubleshooting

If a saved profile is missing, check:

- same browser
- same Windows user profile
- same dashboard host and port
- browser site data has not been cleared
- private browsing mode is not in use

If a connection test fails, check:

- server name or named instance
- DNS and firewall path from the API host
- SQL Server certificate policy
- integrated-security account context
- SQL-auth username and password
- required SQL permissions for metadata visibility

More detail:

- [Instance Manager](../operations/instance-manager.md)
- [Connection Manager](../operations/connection-manager.md)

