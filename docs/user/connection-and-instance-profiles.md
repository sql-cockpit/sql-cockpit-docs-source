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

Instance profiles are saved in the active workspace profile store:

- Personal workspace: private to your account.
- Team workspace: shared with members of that team.

They include:

- profile name
- server name
- authentication mode
- SQL username and password when using SQL authentication
- integrated-security setting
- trust-server-certificate setting

Use instance profiles for workflows that do not start with a single database.

## Database Connection Profiles

Database connection profiles are saved in the active workspace profile store:

- Personal workspace: private to your account.
- Team workspace: shared with members of that team.

They include the instance fields plus a database name. They do not automatically create or update rows in `Sync.TableConfig`.

Use database connection profiles when planning or validating source and destination database work.

## Workspace Switching And Sharing

Use the workspace switcher in the dashboard header to choose where profiles are loaded from and saved to.

- In personal workspace, saved profiles stay private.
- In team workspace, profile changes are visible to team members.
- `Share To Team` in Connection Manager and Instance Manager copies selected personal profiles into a team workspace.

Primary benefit: teams can share reusable profiles without sending passwords through chat, email, or tickets.

## Workspace Use Cases

### 1. Team onboarding without password handoff

- Existing operator shares baseline profiles to the team workspace.
- New teammate switches to that team workspace and starts using the same targets.
- Result: no manual password copy/paste between people.

### 2. Shift handover for estate monitoring

- Day and night operators use the same team workspace.
- Instance profiles remain consistent for estate and agent workflows.
- Result: faster handover and less risk of target mismatch.

### 3. Incident response collaboration

- Add responder to team and have them switch to the team workspace.
- Shared profiles are immediately available for investigation.
- Result: access is controlled by membership, not ad-hoc credential sharing.

### 4. Personal sandbox isolation

- Keep experimental or one-off profiles in personal workspace only.
- Share to team only after validation.
- Result: team workspace stays clean and operationally focused.

## Safe Profile Handling

1. Prefer integrated security where the workstation account is the approved operator identity.
2. Avoid saving SQL-auth passwords on shared workstations.
3. Share SQL-auth profiles to teams only when required by target policy.
4. Test shared profiles before using them in Server Explorer, Agent Manager, or sync planning.
5. Delete stale profiles after server aliases, roles, or credentials change.

## Troubleshooting

If a saved profile is missing, check:

- active workspace selection (personal vs team)
- team membership for the selected team workspace
- profile was saved to the same workspace you are viewing
- profile may be in personal workspace and not yet shared to team workspace

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

